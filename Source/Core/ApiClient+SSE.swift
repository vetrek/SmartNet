import Foundation

// MARK: - Server-Sent Events

public extension ApiClient {
  /// Opens a Server-Sent Events stream for the endpoint and reconnects until the consuming task is cancelled.
  ///
  /// Headers and pre-request middlewares are re-applied on every connection, and `Last-Event-ID` is sent after the first event id.
  /// Non-2xx responses run post-response middlewares first, so a middleware returning `.retryRequest` (e.g. after a token refresh) reconnects immediately.
  /// Reconnection uses `endpoint.retryPolicy`, falling back to unlimited exponential backoff; a server `retry:` value is the minimum delay.
  /// The stream finishes on 204, and throws on non-retryable statuses, a non `text/event-stream` response, or exhausted retries.
  ///
  /// - Parameters:
  ///   - endpoint: The endpoint to stream from.
  ///   - idleTimeout: Seconds without any received byte (heartbeats included) before reconnecting.
  /// - Returns: A stream of events.
  func serverSentEvents<E: Requestable>(
    with endpoint: E,
    idleTimeout: TimeInterval = 45
  ) -> AsyncThrowingStream<SSEEvent, Error> {
    makeStream(for: endpoint, idleTimeout: idleTimeout) {
      if case .event(let event) = $0 { event } else { nil }
    }
  }

  /// Same stream as `serverSentEvents`, with connection lifecycle interleaved in the order it happened.
  ///
  /// Yields `.connection(.opened)`, `.connection(.closed(reason))` and `.connection(.reconnecting(in:reason:))` between events.
  /// Each lifecycle event is also logged at `.info`.
  func serverSentEventsWithLifecycle<E: Requestable>(
    with endpoint: E,
    idleTimeout: TimeInterval = 45
  ) -> AsyncThrowingStream<SSEStreamItem, Error> {
    makeStream(for: endpoint, idleTimeout: idleTimeout) { $0 }
  }
}

extension ApiClient {
  func makeStream<E: Requestable, Element: Sendable>(
    for endpoint: E,
    idleTimeout: TimeInterval,
    element: @escaping @Sendable (SSEStreamItem) -> Element?
  ) -> AsyncThrowingStream<Element, Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          try await streamEvents(from: endpoint, idleTimeout: idleTimeout) { item in
            if let value = element(item) { continuation.yield(value) }
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: Task.isCancelled ? nil : error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  static let defaultStreamRetryPolicy = ExponentialBackoffRetryPolicy(maxRetries: .max, maxDelay: 30, conditions: .all)

  func streamEvents<E: Requestable>(
    from endpoint: E,
    idleTimeout: TimeInterval,
    emit: (SSEStreamItem) -> Void
  ) async throws {
    guard let configuration = session?.configuration else { throw NetworkError.invalidSessions }
    configuration.timeoutIntervalForRequest = idleTimeout
    let streamSession = URLSession(configuration: configuration, delegate: StreamSessionDelegate(client: self), delegateQueue: nil)
    defer { streamSession.invalidateAndCancel() }

    let retryPolicy = endpoint.retryPolicy ?? Self.defaultStreamRetryPolicy
    var parser = SSEParser()
    var attempt = 0

    func report(_ event: SSEConnectionEvent) {
      SmartNetLogger.shared.info("[SSE] \(event)")
      emit(.connection(event))
    }

    while true {
      var failure: NetworkError?
      var middlewareRetry = false
      var reason = SSEDisconnectReason.streamEnded
      var isOpen = false
      let request = try streamRequest(for: endpoint, lastEventID: parser.lastEventID, idleTimeout: idleTimeout)
      do {
        let (bytes, response) = try await streamSession.bytes(for: request)
        if let error = validate(response: response, data: nil) {
          middlewareRetry = try await middlewaresRequestRetry(for: endpoint, request: request, response: response)
          failure = error
          reason = middlewareRetry ? .middlewareRetry : .failure(error)
        } else if response.httpStatusCode == 204 {
          return
        } else if response.mimeType != "text/event-stream" {
          throw NetworkError.unexpectedContentType(response.mimeType)
        } else {
          isOpen = true
          report(.opened(attempt: attempt))
          attempt = 0
          for try await byte in bytes {
            if let event = parser.consume(byte) { emit(.event(event)) }
          }
        }
      } catch let error as URLError where error.code != .cancelled {
        let resolved = resolve(error: error)
        failure = resolved
        reason = resolved == .timeout ? .idleTimeout : .failure(resolved)
      } catch {
        if isOpen { report(.closed(.cancelled)) }
        throw error
      }
      if isOpen { report(.closed(reason)) }

      if middlewareRetry {
        guard attempt < retryPolicy.maxRetries else { throw NetworkError.middlewareMaxRetry }
      } else if !retryPolicy.shouldRetry(for: failure ?? .connectionLost, attempt: attempt) {
        guard let failure else { return }
        throw failure
      }

      let delay = middlewareRetry && attempt == 0
        ? 0
        : max(parser.reconnectionTime ?? 0, retryPolicy.delay(forAttempt: attempt, error: failure))
      attempt += 1
      report(.reconnecting(in: delay, reason: reason))
      try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
  }

  private func streamRequest<E: Requestable>(for endpoint: E, lastEventID: String, idleTimeout: TimeInterval) throws -> URLRequest {
    var request = try prepareRequest(for: endpoint)
    request.timeoutInterval = idleTimeout
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    if !lastEventID.isEmpty {
      request.setValue(lastEventID, forHTTPHeaderField: "Last-Event-ID")
    }
    return request
  }

  private func middlewaresRequestRetry<E: Requestable>(for endpoint: E, request: URLRequest, response: URLResponse) async throws -> Bool {
    guard endpoint.allowMiddlewares, let url = request.url else { return false }
    let groups = middlewareGroups(for: url)
    do {
      return try await shouldRetryAfterPostResponse(groups.global + groups.path, data: nil, response: response, error: nil)
    } catch {
      throw NetworkError.middleware(error)
    }
  }
}

private final class StreamSessionDelegate: NSObject, URLSessionDelegate {
  let client: ApiClient

  init(client: ApiClient) {
    self.client = client
  }

  func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    client.urlSession(session, didReceive: challenge, completionHandler: completionHandler)
  }
}
