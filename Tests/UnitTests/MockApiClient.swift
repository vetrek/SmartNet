import Foundation
import Combine
@testable import SmartNet

/// A mock implementation of ApiClientProtocol for testing purposes.
/// Allows configuring responses and tracking method calls.
public final class MockApiClient: ApiClientProtocol {

  // MARK: - Configuration

  public var config: NetworkConfigurable

  // MARK: - Mock Response Configuration

  /// Set this to return a specific Decodable response
  public var mockDecodableResponse: Any?

  /// Set this to return a specific Data response
  public var mockDataResponse: Data?

  /// Set this to return a specific String response
  public var mockStringResponse: String?

  /// Set this to throw a specific error
  public var mockError: NetworkError?

  // MARK: - Call Tracking

  /// Tracks all endpoints that were requested
  public var requestedEndpoints: [any Requestable] = []

  /// Tracks headers updates
  public var headersUpdates: [[String: String]] = []

  /// Tracks added middlewares
  public var addedMiddlewares: [any MiddlewareProtocol] = []

  /// Tracks if destroy was called
  public var destroyCalled = false

  // MARK: - Initialization

  public init(config: NetworkConfigurable = NetworkConfiguration(baseURL: URL(string: "https://mock.test")!)) {
    self.config = config
  }

  // MARK: - Headers Management

  public func updateHeaders(_ headers: [String: String]) {
    headersUpdates.append(headers)
    config.headers.merge(headers) { $1 }
  }

  public func setHeaders(_ headers: [String: String]) {
    config.headers = headers
  }

  public func cleanHeaders() {
    config.headers = [:]
  }

  public func removeHeaders(keys: [String]) {
    keys.forEach { config.headers.removeValue(forKey: $0) }
  }

  // MARK: - Middleware Management

  public func addMiddleware(_ middleware: any MiddlewareProtocol) {
    addedMiddlewares.append(middleware)
  }

  public func removeMiddleware(for component: String) {
    addedMiddlewares.removeAll { $0.pathComponent == component }
  }

  public func removeMiddleware(_ middleware: any MiddlewareProtocol) {
    addedMiddlewares.removeAll { $0.id == middleware.id }
  }

  // MARK: - Async/Await Requests

  public func request<D: Decodable, E: Requestable>(
    with endpoint: E,
    decoder: JSONDecoder,
    progressHUD: SNProgressHUD?
  ) async throws -> D where D == E.Response {
    requestedEndpoints.append(endpoint)
    if let error = mockError { throw error }
    guard let response = mockDecodableResponse as? D else {
      throw NetworkError.parsingFailed
    }
    return response
  }

  public func request<E: Requestable>(
    with endpoint: E,
    progressHUD: SNProgressHUD?
  ) async throws -> Data where E.Response == Data {
    requestedEndpoints.append(endpoint)
    if let error = mockError { throw error }
    guard let response = mockDataResponse else {
      throw NetworkError.emptyResponse
    }
    return response
  }

  public func request<E: Requestable>(
    with endpoint: E,
    progressHUD: SNProgressHUD?
  ) async throws -> String where E.Response == String {
    requestedEndpoints.append(endpoint)
    if let error = mockError { throw error }
    guard let response = mockStringResponse else {
      throw NetworkError.emptyResponse
    }
    return response
  }

  public func request<E: Requestable>(
    with endpoint: E,
    progressHUD: SNProgressHUD?
  ) async throws where E.Response == Void {
    requestedEndpoints.append(endpoint)
    if let error = mockError { throw error }
  }

  // MARK: - Closure-Based Requests

  @discardableResult
  public func request<D: Decodable, E: Requestable>(
    with endpoint: E,
    decoder: JSONDecoder,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?,
    completion: @escaping (Response<D>) -> Void
  ) -> NetworkCancellable? where D == E.Response {
    requestedEndpoints.append(endpoint)
    queue.async {
      if let error = self.mockError {
        completion(Response(result: .failure(error)))
      } else if let response = self.mockDecodableResponse as? D {
        completion(Response(result: .success(response)))
      } else {
        completion(Response(result: .failure(.parsingFailed)))
      }
    }
    return nil
  }

  @discardableResult
  public func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?,
    completion: @escaping (Response<Data>) -> Void
  ) -> NetworkCancellable? where E.Response == Data {
    requestedEndpoints.append(endpoint)
    queue.async {
      if let error = self.mockError {
        completion(Response(result: .failure(error)))
      } else if let response = self.mockDataResponse {
        completion(Response(result: .success(response)))
      } else {
        completion(Response(result: .failure(.emptyResponse)))
      }
    }
    return nil
  }

  @discardableResult
  public func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?,
    completion: @escaping (Response<String>) -> Void
  ) -> NetworkCancellable? where E.Response == String {
    requestedEndpoints.append(endpoint)
    queue.async {
      if let error = self.mockError {
        completion(Response(result: .failure(error)))
      } else if let response = self.mockStringResponse {
        completion(Response(result: .success(response)))
      } else {
        completion(Response(result: .failure(.emptyResponse)))
      }
    }
    return nil
  }

  @discardableResult
  public func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?,
    completion: @escaping (Response<Void>) -> Void
  ) -> NetworkCancellable? where E.Response == Void {
    requestedEndpoints.append(endpoint)
    queue.async {
      if let error = self.mockError {
        completion(Response(result: .failure(error)))
      } else {
        completion(Response(result: .success(())))
      }
    }
    return nil
  }

  // MARK: - Combine Publishers

  public func request<D: Decodable, E: Requestable>(
    with endpoint: E,
    decoder: JSONDecoder,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?
  ) -> AnyPublisher<D, Error> where D == E.Response {
    requestedEndpoints.append(endpoint)
    if let error = mockError {
      return Fail(error: error).eraseToAnyPublisher()
    }
    guard let response = mockDecodableResponse as? D else {
      return Fail(error: NetworkError.parsingFailed).eraseToAnyPublisher()
    }
    return Just(response)
      .setFailureType(to: Error.self)
      .receive(on: queue)
      .eraseToAnyPublisher()
  }

  public func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?
  ) -> AnyPublisher<Data, Error> where E.Response == Data {
    requestedEndpoints.append(endpoint)
    if let error = mockError {
      return Fail(error: error).eraseToAnyPublisher()
    }
    guard let response = mockDataResponse else {
      return Fail(error: NetworkError.emptyResponse).eraseToAnyPublisher()
    }
    return Just(response)
      .setFailureType(to: Error.self)
      .receive(on: queue)
      .eraseToAnyPublisher()
  }

  public func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?
  ) -> AnyPublisher<String, Error> where E.Response == String {
    requestedEndpoints.append(endpoint)
    if let error = mockError {
      return Fail(error: error).eraseToAnyPublisher()
    }
    guard let response = mockStringResponse else {
      return Fail(error: NetworkError.emptyResponse).eraseToAnyPublisher()
    }
    return Just(response)
      .setFailureType(to: Error.self)
      .receive(on: queue)
      .eraseToAnyPublisher()
  }

  public func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?
  ) -> AnyPublisher<Void, Error> where E.Response == Void {
    requestedEndpoints.append(endpoint)
    if let error = mockError {
      return Fail(error: error).eraseToAnyPublisher()
    }
    return Just(())
      .setFailureType(to: Error.self)
      .receive(on: queue)
      .eraseToAnyPublisher()
  }

  // MARK: - Lifecycle

  public func destroy() {
    destroyCalled = true
  }

  // MARK: - Helpers

  /// Resets all tracking and mock values
  public func reset() {
    mockDecodableResponse = nil
    mockDataResponse = nil
    mockStringResponse = nil
    mockError = nil
    requestedEndpoints = []
    headersUpdates = []
    addedMiddlewares = []
    destroyCalled = false
  }
}
