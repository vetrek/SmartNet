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
          SmartNetLogger.shared.debug("Parsing error: \(error)")
          completion(response.convertedTo(result: .failure(.parsingFailed)))
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
      case .success:
        completion(response.convertedTo(result: .success(())))
      case .failure(let error):
        guard case .emptyResponse = error else {
          if let error = response.result.error as? NetworkError {
            completion(response.convertedTo(result: .failure(error)))
          } else {
            completion(response.convertedTo(result: .failure(.networkFailure)))
          }
          return
        }
        completion(response.convertedTo(result: .success(())))
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
    let request: URLRequest
    do {
      request = try prepareRequest(for: endpoint)
    } catch {
      completion(
        Response(
          result: .failure(error),
          session: session
        )
      )
      return nil
    }

    progressHUD?.show()

    return runDataTask(
      endpoint: endpoint,
      request: request,
      queue: queue,
      progressHUD: progressHUD,
      retryCount: 0,
      completion: completion
    )
  }

  func applyPreRequestMiddlewares(
    to request: inout URLRequest
  ) throws {
    guard let url = request.url, !middlewares.isEmpty else { return }

    let groups = middlewareGroups(for: url)

    for middleware in groups.global {
      try middleware.preRequest(&request)
    }

    for middleware in groups.path {
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
    for middleware in middlewares {
      let result = try await middleware.postResponse(
        data: data,
        response: response,
        error: error
      )

      switch result {
      case .next:
        continue
      case .retryRequest:
        return true
      }
    }

    return false
  }

  func runDataTask<E>(
    endpoint: E,
    request: URLRequest,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil,
    retryCount: Int = 0,
    completion: @escaping (Response<Data>) -> Void
  ) -> NetworkCancellable? where E : Requestable {
    @Sendable func responseBlock(_ response: Response<Data>) {
      queue.async {
        completion(response)
      }
    }

    // Get effective retry policy (endpoint override or config default)
    let retryPolicy = endpoint.retryPolicy ?? config.retryPolicy

    // Check if max retries exceeded
    guard retryCount <= retryPolicy.maxRetries else {
      responseBlock(
        Response(
          result: .failure(.middlewareMaxRetry),
          session: session,
          request: request,
          response: nil
        )
      )
      return nil
    }

    let startTime = Date()
    let currentRequest = request

    let task = session?.dataTask(
      with: currentRequest
    ) { (data, response, error) in
      Task { [weak self] in
        defer {
          DispatchQueue.main.async {
            progressHUD?.dismiss()
          }
        }

        guard let self else { return }

        // Print cURL
        if (self.config.debug || endpoint.debugRequest), let session = self.session {
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
            request: currentRequest,
            response: response,
            data: data
          )
        }

        /// Schedules a retry with delay based on the retry policy.
        func scheduleRetryWithDelay(for error: NetworkError? = nil) {
          let delay = retryPolicy.delay(forAttempt: retryCount, error: error)

          @Sendable func performRetry() {
            do {
              let retriedRequest = try self.prepareRequest(for: endpoint)
              _ = self.runDataTask(
                endpoint: endpoint,
                request: retriedRequest,
                queue: queue,
                progressHUD: progressHUD,
                retryCount: retryCount + 1,
                completion: completion
              )
            } catch {
              responseBlock(
                Response(
                  result: .failure(error),
                  session: self.session,
                  request: currentRequest,
                  response: response
                )
              )
            }
          }

          if delay > 0 {
            SmartNetLogger.shared.debug("[Retry] Attempt \(retryCount + 1)/\(retryPolicy.maxRetries) after \(String(format: "%.2f", delay))s delay")
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { performRetry() }
          } else {
            SmartNetLogger.shared.debug("[Retry] Attempt \(retryCount + 1)/\(retryPolicy.maxRetries) immediately")
            performRetry()
          }
        }

        /// Checks if the error should trigger a retry based on the policy.
        func shouldRetryForError(_ error: NetworkError) -> Bool {
          retryCount < retryPolicy.maxRetries && retryPolicy.shouldRetry(for: error, attempt: retryCount)
        }

        // Run postResponse Middlewares
        if endpoint.allowMiddlewares,
           let url = currentRequest.url,
           !middlewares.isEmpty {
          do {
            let groups = self.middlewareGroups(for: url)

            if try await self.shouldRetryAfterPostResponse(
              groups.global,
              data: data,
              response: response,
              error: error
            ) {
              // Middleware requested retry - check if policy allows
              if retryCount < retryPolicy.maxRetries {
                scheduleRetryWithDelay()
                return
              }
            }

            if try await self.shouldRetryAfterPostResponse(
              groups.path,
              data: data,
              response: response,
              error: error
            ) {
              // Middleware requested retry - check if policy allows
              if retryCount < retryPolicy.maxRetries {
                scheduleRetryWithDelay()
                return
              }
            }
          } catch {
            responseBlock(
              Response(
                result: .failure(.middleware(error)),
                session: session,
                request: currentRequest,
                response: response
              )
            )
            return
          }
        }

        // Check error and apply retry policy
        if let requestError = error {
          let networkError = self.getRequestError(
            data: data,
            response: response,
            requestError: requestError
          )

          // Check if we should retry based on the error
          if shouldRetryForError(networkError) {
            scheduleRetryWithDelay(for: networkError)
            return
          }

          responseBlock(
            Response(
              result: .failure(networkError),
              session: self.session,
              request: currentRequest,
              response: response
            )
          )
          return
        }

        // Make sure have a response
        guard let response else {
          return
        }

        // Check HTTP response status code is within accepted range
        if let validationError = self.validate(response: response, data: data) {
          // Check if we should retry based on the validation error (e.g., 5xx, 429)
          if shouldRetryForError(validationError) {
            scheduleRetryWithDelay(for: validationError)
            return
          }

          responseBlock(
            Response(
              result: .failure(validationError),
              session: self.session,
              request: currentRequest,
              response: response
            )
          )
          return
        }

        guard let data else {
          responseBlock(
            Response(
              result: .failure(.emptyResponse),
              session: self.session,
              request: currentRequest,
              response: response
            )
          )
          return
        }

        // Success Response
        responseBlock(
          Response(
            result: .success(data),
            session: self.session,
            request: currentRequest,
            response: response
          )
        )
      }
    }
    task?.resume()
    return task
  }
}
