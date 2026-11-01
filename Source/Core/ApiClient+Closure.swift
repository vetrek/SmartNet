//
//  ApiClient+Closure.swift
//
//  Copyright (c) 2021 Valerio69 (valerio.alsebas@gmail.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//


import Foundation

// MARK: - Networking Closure

public extension ApiClient {

  /// Create a request and convert the reponse `Data` to a `Decodable` object
  /// - Parameters:
  ///   - endpoint: The service `Endpoint`
  ///   - decoder: Json Decoder
  ///   - queue: completiuon DispatchQueue
  ///   - completion: response completion
  /// - Returns: Return a cancellable Network Request
  @discardableResult
  func request<D, E>(
    with endpoint: E,
    decoder: JSONDecoder = .default,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil,
    completion: @escaping (Response<E.Response>) -> Void
  ) -> NetworkCancellable? where D: Decodable, D == E.Response, E: Requestable {
    dataRequest(with: endpoint, queue: queue, progressHUD: progressHUD) { response in
      switch response.result {
      case .success(let data):
        do {
          let responseObject = try decoder.decode(D.self, from: data)
          completion(response.convertedTo(result: .success(responseObject)))
        } catch {
          let networkError = NetworkError.parsingFailed(from: error)
          SmartNetLogger.shared.debug("Parsing error: \(networkError.description)")
          completion(response.convertedTo(result: .failure(networkError)))
        }
      case .failure(let error):
        completion(response.convertedTo(result: .failure(error)))
      }
    }
  }

  /// Create a request which ignore the response `Data`
  /// - Parameters:
  ///   - endpoint: The service `Endpoint`
  ///   - queue: completiuon DispatchQueue
  ///   - completion: response completion
  /// - Returns: Return a cancellable Network Request
  @discardableResult
  func request<E>(
    with endpoint: E,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil,
    completion: @escaping (Response<E.Response>) -> Void
  ) -> NetworkCancellable? where E: Requestable, E.Response == Data {
    dataRequest(with: endpoint, queue: queue, progressHUD: progressHUD, completion: completion)
  }

  /// Create a request and convert the reponse `Data` to `String`
  /// - Parameters:
  ///   - endpoint: The service `Endpoint`
  ///   - queue: completiuon DispatchQueue
  ///   - completion: response completion
  /// - Returns: Return a cancellable Network Request
  @discardableResult
  func request<E>(
    with endpoint: E,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil,
    completion: @escaping (Response<E.Response>) -> Void
  ) -> NetworkCancellable? where E: Requestable, E.Response == String {
    dataRequest(with: endpoint, queue: queue, progressHUD: progressHUD) { response in
      switch response.result {
      case .success(let data):
        guard
          let string = String(data: data, encoding: .utf8)
        else {
          completion(response.convertedTo(result: .failure(.dataToStringFailure(data: data))))
          return
        }
        completion(response.convertedTo(result: .success(string)))
      case .failure(let error):
        completion(response.convertedTo(result: .failure(error)))
      }
    }
  }

  /// Create a request which ignore the response `Data`
  /// - Parameters:
  ///   - endpoint: The service `Endpoint`
  ///   - queue: completiuon DispatchQueue
  ///   - completion: response completion
  /// - Returns: Return a cancellable Network Request
  @discardableResult
  func request<E>(
    with endpoint: E,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil,
    completion: @escaping (Response<E.Response>) -> Void
  ) -> NetworkCancellable? where E: Requestable, E.Response == Void {
    dataRequest(with: endpoint, queue: queue, progressHUD: progressHUD) { response in
      switch response.result {
      case .success, .failure(.emptyResponse):
        completion(response.convertedTo(result: .success(())))
      case .failure(let error):
        completion(response.convertedTo(result: .failure(error)))
      }
    }
  }

}

// MARK: - Main Request Function
extension ApiClient {
  func prepareRequest<E>(for endpoint: E) throws(NetworkError) -> URLRequest where E: Requestable {
    var request = try endpoint.urlRequest(with: config)
    if endpoint.allowMiddlewares {
      do {
        try applyPreRequestMiddlewares(to: &request)
      } catch {
        throw NetworkError.middleware(error)
      }
    }
    return request
  }

  @discardableResult
  func dataRequest<E>(
    with endpoint: E,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil,
    completion: @escaping (Response<Data>) -> Void
  ) -> NetworkCancellable? where E : Requestable {
    Task {
      let response = await self.response(for: endpoint, progressHUD: progressHUD)
      queue.async { completion(response) }
    }
  }

  func applyPreRequestMiddlewares(
    to request: inout URLRequest
  ) throws {
    guard let url = request.url, !middlewares.isEmpty else { return }

    let groups = middlewareGroups(for: url)
    for middleware in groups.global + groups.path {
      try middleware.preRequest(&request)
    }
  }

  func middlewareGroups(for url: URL) -> (global: [any MiddlewareProtocol], path: [any MiddlewareProtocol]) {
    let path = url.path

    var globalMiddlewares = [any MiddlewareProtocol]()
    var pathMiddlewares = [any MiddlewareProtocol]()

    middlewares.forEach {
      // Global matchers (pattern "/") go to global group
      if $0.pathMatcher.pattern == "/" {
        globalMiddlewares.append($0)
      } else if $0.pathMatcher.matches(path: path) {
        pathMiddlewares.append($0)
      }
    }

    return (global: globalMiddlewares, path: pathMiddlewares)
  }

  func shouldRetryAfterPostResponse(
    _ middlewares: [any MiddlewareProtocol],
    data: Data?,
    response: URLResponse?,
    error: Error?
  ) async throws -> Bool {
    for middleware in middlewares where try await middleware.postResponse(data: data, response: response, error: error) == .retryRequest {
      return true
    }
    return false
  }

  func response<E>(for endpoint: E, progressHUD: SNProgressHUD? = nil) async -> Response<Data> where E: Requestable {
    var request: URLRequest
    do {
      request = try prepareRequest(for: endpoint)
    } catch {
      return Response(result: .failure(error), session: session)
    }

    if let progressHUD { DispatchQueue.main.async { progressHUD.show() } }
    defer { if let progressHUD { DispatchQueue.main.async { progressHUD.dismiss() } } }

    let retryPolicy = endpoint.retryPolicy ?? config.retryPolicy
    var attempt = 0
    while true {
      let exchange = await send(request, debug: endpoint.debugRequest ?? config.debug)
      let response = exchange.response
      switch await outcome(of: endpoint, request: request, exchange: exchange, attempt: attempt, retryPolicy: retryPolicy) {
      case .finish(let result):
        return Response(result: result, session: session, request: request, response: response)
      case .retry(let error):
        let delay = retryPolicy.delay(forAttempt: attempt, error: error)
        if delay > 0 {
          SmartNetLogger.shared.debug("[Retry] Attempt \(attempt + 1)/\(retryPolicy.maxRetries) after \(String(format: "%.2f", delay))s delay")
        } else {
          SmartNetLogger.shared.debug("[Retry] Attempt \(attempt + 1)/\(retryPolicy.maxRetries) immediately")
        }
        do {
          try await Task.sleep(for: .seconds(max(delay, 0)))
          request = try prepareRequest(for: endpoint)
        } catch {
          return Response(result: .failure(error as? NetworkError ?? .cancelled), session: session, request: request, response: response)
        }
        attempt += 1
      }
    }
  }

  private func send(_ request: URLRequest, debug: Bool) async -> Exchange {
    let session = self.session
    let startTime = Date()
    let result: Exchange
    do {
      guard let session else { throw URLError(.cancelled) }
      let (data, response) = try await session.data(for: request)
      result = (data, response, nil)
    } catch {
      result = (nil, nil, error)
    }

    if debug, let session {
      let elapsed = Date().timeIntervalSince(startTime)
      let ms = Int((elapsed.truncatingRemainder(dividingBy: 1)) * 1000)
      if elapsed < 1 {
        SmartNetLogger.shared.debug("[API Time] Took: \(ms) ms")
      } else {
        let seconds = Int(elapsed)
        SmartNetLogger.shared.debug("[API Time] Took: \(seconds)s \(ms)ms")
      }

      ApiClient.printCurl(
        session: session,
        request: request,
        response: result.response,
        data: result.data
      )
    }
    return result
  }

  private func outcome<E>(
    of endpoint: E,
    request: URLRequest,
    exchange: Exchange,
    attempt: Int,
    retryPolicy: RetryPolicy
  ) async -> AttemptOutcome where E: Requestable {
    let (data, response, error) = exchange
    let canRetry = attempt < retryPolicy.maxRetries

    if endpoint.allowMiddlewares, let url = request.url, !middlewares.isEmpty {
      do {
        let groups = middlewareGroups(for: url)
        if try await shouldRetryAfterPostResponse(groups.global + groups.path, data: data, response: response, error: error) {
          return canRetry ? .retry(nil) : .finish(.failure(.middlewareMaxRetry))
        }
      } catch {
        return .finish(.failure(.middleware(error)))
      }
    }

    let failure: NetworkError
    if let error {
      failure = getRequestError(data: data, response: response, requestError: error)
    } else if let response, let validationError = validate(response: response, data: data) {
      failure = validationError
    } else if let data {
      return .finish(.success(data))
    } else {
      return .finish(.failure(.emptyResponse))
    }

    return canRetry && retryPolicy.shouldRetry(for: failure, attempt: attempt) ? .retry(failure) : .finish(.failure(failure))
  }
}

private typealias Exchange = (data: Data?, response: URLResponse?, error: Error?)

private enum AttemptOutcome {
  case finish(Result<Data>)
  case retry(NetworkError?)
}
