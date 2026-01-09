//
//  ApiClientProtocol.swift
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
import Combine

/// Protocol defining the core API client interface for making network requests.
/// Enables dependency injection and easy mocking for testing.
public protocol ApiClientProtocol: AnyObject {

  // MARK: - Configuration

  /// The network configuration for this client.
  var config: NetworkConfigurable { get }

  // MARK: - Headers Management

  /// Merges the provided headers with existing headers.
  func updateHeaders(_ headers: [String: String])

  /// Replaces all headers with the provided headers.
  func setHeaders(_ headers: [String: String])

  /// Removes all headers.
  func cleanHeaders()

  /// Removes headers for the specified keys.
  func removeHeaders(keys: [String])

  // MARK: - Middleware Management

  /// Adds a middleware to the client.
  func addMiddleware(_ middleware: any MiddlewareProtocol)

  /// Removes all middlewares for a specific path component.
  func removeMiddleware(for component: String)

  /// Removes a specific middleware.
  func removeMiddleware(_ middleware: any MiddlewareProtocol)

  // MARK: - Async/Await Requests

  /// Makes a request and decodes the response to the specified Decodable type.
  func request<D: Decodable, E: Requestable>(
    with endpoint: E,
    decoder: JSONDecoder,
    progressHUD: SNProgressHUD?
  ) async throws -> D where D == E.Response

  /// Makes a request and returns raw Data.
  func request<E: Requestable>(
    with endpoint: E,
    progressHUD: SNProgressHUD?
  ) async throws -> Data where E.Response == Data

  /// Makes a request and returns a String.
  func request<E: Requestable>(
    with endpoint: E,
    progressHUD: SNProgressHUD?
  ) async throws -> String where E.Response == String

  /// Makes a request with no expected response body.
  func request<E: Requestable>(
    with endpoint: E,
    progressHUD: SNProgressHUD?
  ) async throws where E.Response == Void

  // MARK: - Closure-Based Requests

  /// Makes a request and decodes the response to the specified Decodable type.
  @discardableResult
  func request<D: Decodable, E: Requestable>(
    with endpoint: E,
    decoder: JSONDecoder,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?,
    completion: @escaping (Response<D>) -> Void
  ) -> NetworkCancellable? where D == E.Response

  /// Makes a request and returns raw Data.
  @discardableResult
  func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?,
    completion: @escaping (Response<Data>) -> Void
  ) -> NetworkCancellable? where E.Response == Data

  /// Makes a request and returns a String.
  @discardableResult
  func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?,
    completion: @escaping (Response<String>) -> Void
  ) -> NetworkCancellable? where E.Response == String

  /// Makes a request with no expected response body.
  @discardableResult
  func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?,
    completion: @escaping (Response<Void>) -> Void
  ) -> NetworkCancellable? where E.Response == Void

  // MARK: - Combine Publishers

  /// Makes a request and returns a publisher that emits the decoded response.
  func request<D: Decodable, E: Requestable>(
    with endpoint: E,
    decoder: JSONDecoder,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?
  ) -> AnyPublisher<D, Error> where D == E.Response

  /// Makes a request and returns a publisher that emits raw Data.
  func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?
  ) -> AnyPublisher<Data, Error> where E.Response == Data

  /// Makes a request and returns a publisher that emits a String.
  func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?
  ) -> AnyPublisher<String, Error> where E.Response == String

  /// Makes a request and returns a publisher that emits Void.
  func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue,
    progressHUD: SNProgressHUD?
  ) -> AnyPublisher<Void, Error> where E.Response == Void

  // MARK: - Lifecycle

  /// Cancels all tasks and releases resources.
  func destroy()
}

// MARK: - Default Parameter Extensions

public extension ApiClientProtocol {

  // MARK: - Async/Await with defaults

  func request<D: Decodable, E: Requestable>(
    with endpoint: E,
    decoder: JSONDecoder = .default,
    progressHUD: SNProgressHUD? = nil
  ) async throws -> D where D == E.Response {
    try await request(with: endpoint, decoder: decoder, progressHUD: progressHUD)
  }

  func request<E: Requestable>(
    with endpoint: E,
    progressHUD: SNProgressHUD? = nil
  ) async throws -> Data where E.Response == Data {
    try await request(with: endpoint, progressHUD: progressHUD)
  }

  func request<E: Requestable>(
    with endpoint: E,
    progressHUD: SNProgressHUD? = nil
  ) async throws -> String where E.Response == String {
    try await request(with: endpoint, progressHUD: progressHUD)
  }

  func request<E: Requestable>(
    with endpoint: E,
    progressHUD: SNProgressHUD? = nil
  ) async throws where E.Response == Void {
    try await request(with: endpoint, progressHUD: progressHUD)
  }

  // MARK: - Closure-Based with defaults

  @discardableResult
  func request<D: Decodable, E: Requestable>(
    with endpoint: E,
    decoder: JSONDecoder = .default,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil,
    completion: @escaping (Response<D>) -> Void
  ) -> NetworkCancellable? where D == E.Response {
    request(with: endpoint, decoder: decoder, queue: queue, progressHUD: progressHUD, completion: completion)
  }

  @discardableResult
  func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil,
    completion: @escaping (Response<Data>) -> Void
  ) -> NetworkCancellable? where E.Response == Data {
    request(with: endpoint, queue: queue, progressHUD: progressHUD, completion: completion)
  }

  @discardableResult
  func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil,
    completion: @escaping (Response<String>) -> Void
  ) -> NetworkCancellable? where E.Response == String {
    request(with: endpoint, queue: queue, progressHUD: progressHUD, completion: completion)
  }

  @discardableResult
  func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil,
    completion: @escaping (Response<Void>) -> Void
  ) -> NetworkCancellable? where E.Response == Void {
    request(with: endpoint, queue: queue, progressHUD: progressHUD, completion: completion)
  }

  // MARK: - Combine with defaults

  func request<D: Decodable, E: Requestable>(
    with endpoint: E,
    decoder: JSONDecoder = .default,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil
  ) -> AnyPublisher<D, Error> where D == E.Response {
    request(with: endpoint, decoder: decoder, queue: queue, progressHUD: progressHUD)
  }

  func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil
  ) -> AnyPublisher<Data, Error> where E.Response == Data {
    request(with: endpoint, queue: queue, progressHUD: progressHUD)
  }

  func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil
  ) -> AnyPublisher<String, Error> where E.Response == String {
    request(with: endpoint, queue: queue, progressHUD: progressHUD)
  }

  func request<E: Requestable>(
    with endpoint: E,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil
  ) -> AnyPublisher<Void, Error> where E.Response == Void {
    request(with: endpoint, queue: queue, progressHUD: progressHUD)
  }
}
