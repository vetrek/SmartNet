import Foundation
import Testing
@testable import SmartNet

// MARK: - Streaming Stub

final class SSEStubProtocol: URLProtocol, @unchecked Sendable {
  enum Reply {
    case stream(String, status: Int = 200, contentType: String = "text/event-stream", close: Bool = true)
    case fail(URLError.Code)
  }

  typealias Handler = @Sendable (URLRequest, Int) -> Reply

  private static let lock = NSLock()
  private static var handlers: [String: Handler] = [:]
  private static var connections: [String: [(request: URLRequest, date: Date)]] = [:]
  private static var stops: [String: Int] = [:]

  static func register(_ path: String, handler: @escaping Handler) {
    lock.withLock { handlers[path] = handler }
  }

  static func requests(_ path: String) -> [URLRequest] {
    lock.withLock { connections[path, default: []].map(\.request) }
  }

  static func dates(_ path: String) -> [Date] {
    lock.withLock { connections[path, default: []].map(\.date) }
  }

  static func stopCount(_ path: String) -> Int {
    lock.withLock { stops[path, default: 0] }
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let path = request.url?.path ?? ""
    let reply: Reply? = Self.lock.withLock {
      let index = Self.connections[path, default: []].count
      Self.connections[path, default: []].append((request, Date()))
      return Self.handlers[path]?(request, index)
    }
    switch reply {
    case .stream(let body, let status, let contentType, let close):
      let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": contentType])!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      if !body.isEmpty { client?.urlProtocol(self, didLoad: Data(body.utf8)) }
      if close { client?.urlProtocolDidFinishLoading(self) }
    case .fail(let code):
      client?.urlProtocol(self, didFailWithError: URLError(code))
    case nil:
      client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
    }
  }

  override func stopLoading() {
    let path = request.url?.path ?? ""
    Self.lock.withLock { Self.stops[path, default: 0] += 1 }
  }
}

final class TokenBox: @unchecked Sendable {
  private let lock = NSLock()
  private var value: String

  init(_ value: String) { self.value = value }

  var token: String {
    get { lock.withLock { value } }
    set { lock.withLock { value = newValue } }
  }
}

// MARK: - Tests

@Suite("Server-Sent Events")
struct ServerSentEventsTests {
  private func makeClient() -> ApiClient {
    let sessionConfig = URLSessionConfiguration.ephemeral
    sessionConfig.protocolClasses = [SSEStubProtocol.self]
    let config = NetworkConfiguration(baseURL: URL(string: "https://sse.example.com")!, debug: false)
    return ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)
  }

  private func endpoint(_ path: String, retryPolicy: RetryPolicy? = ImmediateRetryPolicy(maxRetries: 3)) -> Endpoint<SSEEvent> {
    Endpoint(path: path, retryPolicy: retryPolicy)
  }

  private func first(_ count: Int, of stream: AsyncThrowingStream<SSEEvent, Error>) async throws -> [SSEEvent] {
    var events = [SSEEvent]()
    for try await event in stream {
      events.append(event)
      if events.count == count { break }
    }
    return events
  }

  private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
  }

    @Test("Streams events and sends stream headers")
  func streamsEvents() async throws {
    let path = "/sse/basic"
    SSEStubProtocol.register(path) { _, _ in .stream("data: a\n\nevent: update\ndata: b\n\n", close: false) }

    let events = try await first(2, of: makeClient().serverSentEvents(with: endpoint(path)))

    #expect(events.map(\.data) == ["a", "b"])
    #expect(events.map(\.event) == ["message", "update"])
    let request = try #require(SSEStubProtocol.requests(path).first)
    #expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
    #expect(request.value(forHTTPHeaderField: "Cache-Control") == "no-cache")
    #expect(request.value(forHTTPHeaderField: "Last-Event-ID") == nil)
  }

    @Test("Reconnects after the server closes, sending Last-Event-ID after the server retry delay")
  func reconnectsWithLastEventID() async throws {
    let path = "/sse/reconnect"
    SSEStubProtocol.register(path) { _, index in
      index == 0 ? .stream("retry: 300\nid: 7\ndata: a\n\n") : .stream("data: b\n\n", close: false)
    }

    let events = try await first(2, of: makeClient().serverSentEvents(with: endpoint(path)))

    #expect(events.map(\.data) == ["a", "b"])
    #expect(events.map(\.id) == ["7", "7"])
    let requests = SSEStubProtocol.requests(path)
    #expect(requests.count == 2)
    #expect(requests.last?.value(forHTTPHeaderField: "Last-Event-ID") == "7")
    let dates = SSEStubProtocol.dates(path)
    #expect(dates[1].timeIntervalSince(dates[0]) >= 0.3)
  }

    @Test("Runs post-response middleware on 401, then reconnects with refreshed headers")
  func refreshesOnUnauthorized() async throws {
    let path = "/sse/auth"
    let token = TokenBox("stale")
    let client = makeClient()
    client.addMiddleware(ApiClient.Middleware(
      pathComponent: "/",
      preRequestCallback: { $0.setValue("Bearer \(token.token)", forHTTPHeaderField: "Authorization") },
      postResponseCallback: { _, response, _ in
        guard (response as? HTTPURLResponse)?.statusCode == 401 else { return .next }
        token.token = "fresh"
        return .retryRequest
      }
    ))
    SSEStubProtocol.register(path) { request, _ in
      request.value(forHTTPHeaderField: "Authorization") == "Bearer fresh"
        ? .stream("data: ok\n\n", close: false)
        : .stream("", status: 401)
    }

    let events = try await first(1, of: client.serverSentEvents(with: endpoint(path, retryPolicy: nil)))

    #expect(events.map(\.data) == ["ok"])
    #expect(SSEStubProtocol.requests(path).map { $0.value(forHTTPHeaderField: "Authorization") } == ["Bearer stale", "Bearer fresh"])
  }

    @Test("Reconnects when no bytes arrive within the idle timeout")
  func idleTimeoutReconnects() async throws {
    let path = "/sse/idle"
    SSEStubProtocol.register(path) { _, index in
      index == 0 ? .stream("id: 1\ndata: a\n\n", close: false) : .stream("data: b\n\n", close: false)
    }

    let events = try await first(2, of: makeClient().serverSentEvents(with: endpoint(path), idleTimeout: 0.3))

    #expect(events.map(\.data) == ["a", "b"])
    #expect(SSEStubProtocol.requests(path).last?.value(forHTTPHeaderField: "Last-Event-ID") == "1")
    #expect(SSEStubProtocol.stopCount(path) >= 1)
  }

    @Test("Task cancellation closes the connection and stops reconnecting")
  func cancellationStops() async throws {
    let path = "/sse/cancel"
    SSEStubProtocol.register(path) { _, _ in .stream("data: a\n\n", close: false) }
    let stream = makeClient().serverSentEvents(with: endpoint(path))
    let received = TokenBox("")

    let task = Task {
      for try await event in stream { received.token = event.data }
    }
    try await waitUntil { received.token == "a" }
    task.cancel()
    let result = await task.result
    try await Task.sleep(nanoseconds: 300_000_000)

    #expect(throws: Never.self) { try result.get() }
    #expect(SSEStubProtocol.stopCount(path) == 1)
    #expect(SSEStubProtocol.requests(path).count == 1)
  }

    @Test("Finishes without error on 204 No Content")
  func finishesOnNoContent() async throws {
    let path = "/sse/no-content"
    SSEStubProtocol.register(path) { _, index in index == 0 ? .stream("", status: 204) : .stream("data: unexpected\n\n") }

    let events = try await first(1, of: makeClient().serverSentEvents(with: endpoint(path)))

    #expect(events.isEmpty)
    #expect(SSEStubProtocol.requests(path).count == 1)
  }

    @Test("Fails on non-retryable status without reconnecting")
  func failsOnClientError() async throws {
    let path = "/sse/not-found"
    SSEStubProtocol.register(path) { _, _ in .stream("", status: 404) }

    await #expect(throws: NetworkError.error(statusCode: 404, data: nil)) {
      try await first(1, of: makeClient().serverSentEvents(with: endpoint(path)))
    }
    #expect(SSEStubProtocol.requests(path).count == 1)
  }

    @Test("Fails when the content type is not text/event-stream")
  func failsOnWrongContentType() async throws {
    let path = "/sse/json"
    SSEStubProtocol.register(path) { _, index in index == 0 ? .stream("{}", contentType: "application/json") : .stream("data: unexpected\n\n") }

    await #expect(throws: NetworkError.unexpectedContentType("application/json")) {
      try await first(1, of: makeClient().serverSentEvents(with: endpoint(path)))
    }
    #expect(SSEStubProtocol.requests(path).count == 1)
  }

    @Test("Fails with the last error once retries are exhausted")
  func failsAfterRetries() async throws {
    let path = "/sse/unavailable"
    SSEStubProtocol.register(path) { _, _ in .stream("", status: 503) }

    await #expect(throws: NetworkError.error(statusCode: 503, data: nil)) {
      try await first(1, of: makeClient().serverSentEvents(with: endpoint(path, retryPolicy: ImmediateRetryPolicy(maxRetries: 2))))
    }
    #expect(SSEStubProtocol.requests(path).count == 3)
  }

    @Test("Retries transport failures, then streams")
  func retriesTransportFailure() async throws {
    let path = "/sse/flaky"
    SSEStubProtocol.register(path) { _, index in
      index == 0 ? .fail(.networkConnectionLost) : .stream("data: a\n\n", close: false)
    }

    let events = try await first(1, of: makeClient().serverSentEvents(with: endpoint(path)))

    #expect(events.map(\.data) == ["a"])
    #expect(SSEStubProtocol.requests(path).count == 2)
  }
}
