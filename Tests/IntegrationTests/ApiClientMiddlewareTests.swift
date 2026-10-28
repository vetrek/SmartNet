import Testing
import Foundation
import Combine
@testable import SmartNet

@Suite("ApiClient Middleware Tests", .serialized)
struct ApiClientMiddlewareTests {

  @Test("Prepare request applies global and path middlewares")
  func prepareRequestAppliesGlobalAndPathMiddlewares() throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    let globalMiddleware = TestMiddleware(
      pathComponent: "/",
      preRequestHandler: { request in
        request.addValue("global", forHTTPHeaderField: "X-Test-Header")
      }
    )

    let pathMiddleware = TestMiddleware(
      pathComponent: "users",
      preRequestHandler: { request in
        request.addValue("path", forHTTPHeaderField: "X-Path-Header")
      }
    )

    client.addMiddleware(globalMiddleware)
    client.addMiddleware(pathMiddleware)

    let endpoint = Endpoint<Data>(
      path: "users",
      method: .get
    )

    let request = try client.prepareRequest(for: endpoint)

    #expect(request.value(forHTTPHeaderField: "X-Test-Header") == "global")
    #expect(request.value(forHTTPHeaderField: "X-Path-Header") == "path")
  }

  @Test("Prepare request skips middlewares when disabled")
  func prepareRequestSkipsMiddlewaresWhenDisabled() throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    let middleware = TestMiddleware(
      pathComponent: "/",
      preRequestHandler: { request in
        request.addValue("value", forHTTPHeaderField: "X-Should-Not-Exist")
      }
    )

    client.addMiddleware(middleware)

    let endpoint = Endpoint<Data>(
      path: "users",
      method: .get,
      allowMiddlewares: false
    )

    let request = try client.prepareRequest(for: endpoint)

    #expect(request.value(forHTTPHeaderField: "X-Should-Not-Exist") == nil)
  }

  @Test("Middleware groups separates global and path targets")
  func middlewareGroupsSeparatesGlobalAndPathTargets() throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    let globalMiddleware = TestMiddleware(pathComponent: "/")
    let pathMiddleware = TestMiddleware(pathComponent: "users")
    client.addMiddleware(globalMiddleware)
    client.addMiddleware(pathMiddleware)

    let url = URL(string: "https://example.com/users/profile")!
    let groups = client.middlewareGroups(for: url)

    #expect(groups.global.count == 1)
    #expect(groups.path.count == 1)
    #expect(groups.global.first?.id == globalMiddleware.id)
    #expect(groups.path.first?.id == pathMiddleware.id)
  }

  @Test("Should retry after post response returns true when middleware requests retry")
  func shouldRetryAfterPostResponseReturnsTrueWhenMiddlewareRequestsRetry() async throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    let retryMiddleware = TestMiddleware(
      pathComponent: "/",
      postResponseHandler: { _, _, _ in
        .retryRequest
      }
    )

    let shouldRetry = try await client.shouldRetryAfterPostResponse(
      [retryMiddleware],
      data: nil,
      response: nil,
      error: nil
    )

    #expect(shouldRetry == true)
  }

  @Test("Should retry after post response returns false when middlewares continue")
  func shouldRetryAfterPostResponseReturnsFalseWhenMiddlewaresContinue() async throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    let middleware = TestMiddleware(
      pathComponent: "/",
      postResponseHandler: { _, _, _ in
        .next
      }
    )

    let shouldRetry = try await client.shouldRetryAfterPostResponse(
      [middleware],
      data: nil,
      response: nil,
      error: nil
    )

    #expect(shouldRetry == false)
  }

  @Test("Remove middleware by path component")
  func removeMiddlewareByPathComponent() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    let middleware1 = TestMiddleware(pathComponent: "users")
    let middleware2 = TestMiddleware(pathComponent: "posts")

    client.addMiddleware(middleware1)
    client.addMiddleware(middleware2)

    client.removeMiddleware(for: "users")

    let url = URL(string: "https://example.com/users/1")!
    let groups = client.middlewareGroups(for: url)

    #expect(groups.path.isEmpty)
  }

  @Test("Remove specific middleware instance")
  func removeSpecificMiddlewareInstance() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    let middleware1 = TestMiddleware(pathComponent: "/")
    let middleware2 = TestMiddleware(pathComponent: "/")

    client.addMiddleware(middleware1)
    client.addMiddleware(middleware2)

    client.removeMiddleware(middleware1)

    let url = URL(string: "https://example.com/test")!
    let groups = client.middlewareGroups(for: url)

    #expect(groups.global.count == 1)
    #expect(groups.global.first?.id == middleware2.id)
  }

  @Test("Middleware retry fails with middlewareMaxRetry after max retries")
  func middlewareRetryFailsWithMaxRetryError() async throws {
    let path = "/middleware-max-retry"
    let (client, requestCount, endpoint) = makeAlwaysRetryClient(path: path, middlewarePath: "/")
    defer { client.destroy(); MockURLProtocol.removeHandler(for: path) }

    await #expect(throws: NetworkError.middlewareMaxRetry) {
      try await client.request(with: endpoint)
    }
    #expect(requestCount.value == 3)
  }

  @Test("Path middleware retry fails with middlewareMaxRetry after max retries")
  func pathMiddlewareRetryFailsWithMaxRetryError() async throws {
    let path = "/middleware-max-retry-path"
    let (client, requestCount, endpoint) = makeAlwaysRetryClient(path: path, middlewarePath: "middleware-max-retry-path")
    defer { client.destroy(); MockURLProtocol.removeHandler(for: path) }

    await #expect(throws: NetworkError.middlewareMaxRetry) {
      try await client.request(with: endpoint)
    }
    #expect(requestCount.value == 3)
  }

  @Test("Middleware retry limit fails closure requests with middlewareMaxRetry")
  func closureMiddlewareRetryFailsWithMaxRetryError() async {
    let path = "/middleware-max-retry-closure"
    let (client, requestCount, endpoint) = makeAlwaysRetryClient(path: path, middlewarePath: "/")
    defer { client.destroy(); MockURLProtocol.removeHandler(for: path) }

    let response: Response<Data> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    #expect(response.result.error as? NetworkError == .middlewareMaxRetry)
    #expect(response.statusCode == 200)
    #expect(requestCount.value == 3)
  }

  @Test("Middleware retry limit fails Combine requests with middlewareMaxRetry")
  func combineMiddlewareRetryFailsWithMaxRetryError() async {
    let path = "/middleware-max-retry-combine"
    let (client, requestCount, endpoint) = makeAlwaysRetryClient(path: path, middlewarePath: "/")
    defer { client.destroy(); MockURLProtocol.removeHandler(for: path) }

    let publisher: AnyPublisher<Data, Error> = client.request(with: endpoint)
    let holder = CancellableHolder()

    let error: Error? = await withCheckedContinuation { continuation in
      let cancellable = publisher
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              continuation.resume(returning: error)
            } else {
              continuation.resume(returning: nil)
            }
          },
          receiveValue: { _ in }
        )
      Task { await holder.store(cancellable) }
    }

    #expect(error as? NetworkError == .middlewareMaxRetry)
    #expect(requestCount.value == 3)
  }

  @Test("Path-matched closure middleware header is sent on every retry")
  func pathMatchedPreRequestHeaderIsSentOnRetries() async throws {
    let (client, _) = createMockClient()
    let path = "/middleware-header-retry"
    defer { client.destroy(); MockURLProtocol.removeHandler(for: path) }

    let requestCount = RequestCounter()
    let authorizedCount = RequestCounter()
    MockURLProtocol.setHandler(for: path) { request in
      requestCount.increment()
      if request.value(forHTTPHeaderField: "Authorization") == "Bearer token" {
        authorizedCount.increment()
      }
      let statusCode = requestCount.value < 3 ? 503 : 200
      let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
      return (response, Data("ok".utf8))
    }

    client.addMiddleware(
      ApiClient.Middleware(
        pathMatcher: ExactPathMatcher(pattern: path),
        preRequestCallback: { request in
          request.setValue("Bearer token", forHTTPHeaderField: "Authorization")
        },
        postResponseCallback: { _, _, _ in .next }
      )
    )

    let endpoint = Endpoint<Data>(path: path, method: .get, retryPolicy: ImmediateRetryPolicy(maxRetries: 2))
    _ = try await client.request(with: endpoint)

    #expect(requestCount.value == 3)
    #expect(authorizedCount.value == 3)
  }

  private func makeAlwaysRetryClient(
    path: String,
    middlewarePath: String
  ) -> (ApiClient, RequestCounter, Endpoint<Data>) {
    let (client, _) = createMockClient()
    let requestCount = RequestCounter()
    MockURLProtocol.setHandler(for: path) { request in
      requestCount.increment()
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, Data("ok".utf8))
    }
    client.addMiddleware(
      TestMiddleware(pathComponent: middlewarePath, postResponseHandler: { _, _, _ in .retryRequest })
    )
    let endpoint = Endpoint<Data>(path: path, method: .get, retryPolicy: ImmediateRetryPolicy(maxRetries: 2))
    return (client, requestCount, endpoint)
  }

  @Test("Closure middleware pre-request header reaches outgoing request")
  func closureMiddlewarePreRequestHeaderIsSent() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy() }

    let path = "/middleware-pre-request-header"
    let receivedHeader = HeaderRecorder()
    MockURLProtocol.setHandler(for: path) { request in
      receivedHeader.record(request.value(forHTTPHeaderField: "Authorization"))
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, Data("ok".utf8))
    }
    defer { MockURLProtocol.removeHandler(for: path) }

    client.addMiddleware(
      ApiClient.Middleware(
        pathComponent: "/",
        preRequestCallback: { request in
          request.setValue("Bearer token", forHTTPHeaderField: "Authorization")
        },
        postResponseCallback: { _, _, _ in .next }
      )
    )

    _ = try await client.request(with: Endpoint<Data>(path: path, method: .get))

    #expect(receivedHeader.value == "Bearer token")
  }

  @Test("Global middlewares run before path middlewares and a global retry skips path ones")
  func globalRetrySkipsPathMiddlewares() async throws {
    let (client, _) = createMockClient()
    let path = "/middleware-order"
    defer { client.destroy(); MockURLProtocol.removeHandler(for: path) }

    let requestCount = RequestCounter()
    MockURLProtocol.setHandler(for: path) { request in
      requestCount.increment()
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("ok".utf8))
    }

    let events = EventRecorder()
    client.addMiddleware(TestMiddleware(
      pathComponent: "middleware-order",
      preRequestHandler: { _ in events.record("pre-path") },
      postResponseHandler: { _, _, _ in events.record("post-path"); return .next }
    ))
    client.addMiddleware(TestMiddleware(
      pathComponent: "/",
      preRequestHandler: { _ in events.record("pre-global") },
      postResponseHandler: { _, _, _ in
        events.record("post-global")
        return requestCount.value == 1 ? .retryRequest : .next
      }
    ))

    let endpoint = Endpoint<Data>(path: path, method: .get, retryPolicy: ImmediateRetryPolicy(maxRetries: 2))
    _ = try await client.request(with: endpoint)

    #expect(requestCount.value == 2)
    #expect(events.values == [
      "pre-global", "pre-path", "post-global",
      "pre-global", "pre-path", "post-global", "post-path"
    ])
  }

  @Test("Throwing post-response middleware fails with middleware error and response metadata")
  func throwingPostResponseMiddlewareFails() async {
    let (client, _) = createMockClient()
    let path = "/middleware-throws"
    defer { client.destroy(); MockURLProtocol.removeHandler(for: path) }

    MockURLProtocol.setHandler(for: path) { request in
      (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, Data("ok".utf8))
    }
    client.addMiddleware(TestMiddleware(pathComponent: "/", postResponseHandler: { _, _, _ in throw URLError(.userAuthenticationRequired) }))

    let response: Response<Data> = await withCheckedContinuation { continuation in
      client.request(with: Endpoint<Data>(path: path, method: .get)) { continuation.resume(returning: $0) }
    }

    #expect(response.error as? NetworkError == .middleware(URLError(.userAuthenticationRequired)))
    #expect(response.statusCode == 201)
    #expect(response.request?.url?.path == path)
  }

  @Test("Progress HUD shows once and dismisses after every attempt, after the completion")
  func progressHUDAcrossRetries() async throws {
    let (client, _) = createMockClient()
    let path = "/middleware-hud-retry"
    defer { client.destroy(); MockURLProtocol.removeHandler(for: path) }

    let requestCount = RequestCounter()
    MockURLProtocol.setHandler(for: path) { request in
      requestCount.increment()
      let statusCode = requestCount.value < 3 ? 503 : 200
      return (HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!, Data("ok".utf8))
    }

    let hud = HUDRecorder()
    let endpoint = Endpoint<Data>(path: path, method: .get, retryPolicy: ImmediateRetryPolicy(maxRetries: 2))
    let eventsAtCompletion: [String] = await withCheckedContinuation { continuation in
      client.request(with: endpoint, progressHUD: hud) { _ in continuation.resume(returning: hud.events.values) }
    }
    await MainActor.run {}

    #expect(requestCount.value == 3)
    #expect(eventsAtCompletion == ["show", "dismiss", "dismiss"])
    #expect(hud.events.values == ["show", "dismiss", "dismiss", "dismiss"])
  }
}

// MARK: - Test Helpers

private final class RequestCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }

  func increment() {
    lock.lock()
    defer { lock.unlock() }
    count += 1
  }
}

private final class HeaderRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var header: String?

  var value: String? {
    lock.lock()
    defer { lock.unlock() }
    return header
  }

  func record(_ value: String?) {
    lock.lock()
    defer { lock.unlock() }
    header = value
  }
}

private struct TestMiddleware: MiddlewareProtocol, Sendable {
  let id = UUID()
  let pathComponent: String
  private let preRequestHandler: (@Sendable (inout URLRequest) throws -> Void)?
  private let postResponseHandler: (@Sendable (Data?, URLResponse?, Error?) async throws -> ApiClient.MiddlewarePostRequestResult)?

  init(
    pathComponent: String,
    preRequestHandler: (@Sendable (inout URLRequest) throws -> Void)? = nil,
    postResponseHandler: (@Sendable (Data?, URLResponse?, Error?) async throws -> ApiClient.MiddlewarePostRequestResult)? = nil
  ) {
    self.pathComponent = pathComponent
    self.preRequestHandler = preRequestHandler
    self.postResponseHandler = postResponseHandler
  }

  func preRequest(_ request: inout URLRequest) throws {
    try preRequestHandler?(&request)
  }

  func postResponse(
    data: Data?,
    response: URLResponse?,
    error: Error?
  ) async throws -> ApiClient.MiddlewarePostRequestResult {
    if let handler = postResponseHandler {
      return try await handler(data, response, error)
    }
    return .next
  }
}

private struct HUDRecorder: SNProgressHUD {
  let events = EventRecorder()
  func show() { events.record("show") }
  func dismiss() { events.record("dismiss") }
}
