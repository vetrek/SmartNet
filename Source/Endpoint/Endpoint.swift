//
//  Endpoint.swift
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

public struct Endpoint<Value>: Requestable {

  public typealias Response = Value

  public var path: String
  public var isFullPath: Bool
  public var method: HTTPMethod
  public var headers: [String: String]
  public var useEndpointHeaderOnly: Bool
  public var queryParameters: QueryParameters?
  public var body: HTTPBody?
  public let form: MultipartFormData? = nil
  public var allowMiddlewares: Bool
  public var debugRequest: Bool
  public var retryPolicy: RetryPolicy?

  public init(
    path: String,
    isFullPath: Bool = false,
    method: HTTPMethod = .get,
    headers: [String: String] = [:],
    useEndpointHeaderOnly: Bool = false,
    queryParameters: QueryParameters? = nil,
    body: HTTPBody? = nil,
    allowMiddlewares: Bool = true,
    debugRequest: Bool = false,
    retryPolicy: RetryPolicy? = nil
  ) {
    self.path = path
    self.isFullPath = isFullPath
    self.method = method
    self.headers = headers
    self.useEndpointHeaderOnly = useEndpointHeaderOnly
    self.queryParameters = queryParameters
    self.body = body
    self.allowMiddlewares = allowMiddlewares
    self.debugRequest = debugRequest
    self.retryPolicy = retryPolicy
  }
}

// MARK: - Endpoint Builder Pattern

/// Static factory methods for creating endpoints with a fluent API.
///
/// Example usage:
/// ```swift
/// let endpoint = Endpoint<User>.get("users/123")
///   .headers(["Authorization": "Bearer token"])
///   .query(["include": "profile"])
///
/// let createEndpoint = Endpoint<User>.post("users")
///   .body(["name": "John", "email": "john@example.com"])
///   .headers(["Content-Type": "application/json"])
/// ```
public extension Endpoint {

  // MARK: - Factory Methods

  /// Creates a GET endpoint.
  static func get(_ path: String, isFullPath: Bool = false) -> Endpoint {
    Endpoint(path: path, isFullPath: isFullPath, method: .get)
  }

  /// Creates a POST endpoint.
  static func post(_ path: String, isFullPath: Bool = false) -> Endpoint {
    Endpoint(path: path, isFullPath: isFullPath, method: .post)
  }

  /// Creates a PUT endpoint.
  static func put(_ path: String, isFullPath: Bool = false) -> Endpoint {
    Endpoint(path: path, isFullPath: isFullPath, method: .put)
  }

  /// Creates a PATCH endpoint.
  static func patch(_ path: String, isFullPath: Bool = false) -> Endpoint {
    Endpoint(path: path, isFullPath: isFullPath, method: .patch)
  }

  /// Creates a DELETE endpoint.
  static func delete(_ path: String, isFullPath: Bool = false) -> Endpoint {
    Endpoint(path: path, isFullPath: isFullPath, method: .delete)
  }

  /// Creates a HEAD endpoint.
  static func head(_ path: String, isFullPath: Bool = false) -> Endpoint {
    Endpoint(path: path, isFullPath: isFullPath, method: .head)
  }

  /// Creates an OPTIONS endpoint.
  static func options(_ path: String, isFullPath: Bool = false) -> Endpoint {
    Endpoint(path: path, isFullPath: isFullPath, method: .options)
  }

  // MARK: - Chainable Modifiers

  /// Sets the request headers.
  func headers(_ headers: [String: String]) -> Endpoint {
    var copy = self
    copy.headers = headers
    return copy
  }

  /// Adds headers to existing headers.
  func addingHeaders(_ headers: [String: String]) -> Endpoint {
    var copy = self
    copy.headers.merge(headers) { _, new in new }
    return copy
  }

  /// Sets a single header.
  func header(_ key: String, _ value: String) -> Endpoint {
    var copy = self
    copy.headers[key] = value
    return copy
  }

  /// Sets query parameters from a dictionary.
  func query(_ parameters: [String: Any]) -> Endpoint {
    var copy = self
    copy.queryParameters = QueryParameters(parameters: parameters)
    return copy
  }

  /// Sets query parameters.
  func query(_ parameters: QueryParameters) -> Endpoint {
    var copy = self
    copy.queryParameters = parameters
    return copy
  }

  /// Sets the request body from a dictionary (JSON encoded).
  func body(_ dictionary: [String: Any], encoding: BodyEncoding = .json()) -> Endpoint {
    var copy = self
    copy.body = HTTPBody(dictionary: dictionary, bodyEncoding: encoding)
    return copy
  }

  /// Sets the request body from an Encodable value.
  func body<T: Encodable>(_ value: T, encoder: JSONEncoder = JSONEncoder()) -> Endpoint {
    var copy = self
    copy.body = HTTPBody(encodable: value, bodyEncoding: .json(encoder: encoder))
    return copy
  }

  /// Sets the request body.
  func body(_ body: HTTPBody) -> Endpoint {
    var copy = self
    copy.body = body
    return copy
  }

  /// Sets whether to use only endpoint headers (ignoring config headers).
  func useEndpointHeadersOnly(_ value: Bool = true) -> Endpoint {
    var copy = self
    copy.useEndpointHeaderOnly = value
    return copy
  }

  /// Sets whether middlewares are allowed for this endpoint.
  func allowMiddlewares(_ value: Bool) -> Endpoint {
    var copy = self
    copy.allowMiddlewares = value
    return copy
  }

  /// Disables middlewares for this endpoint.
  func withoutMiddlewares() -> Endpoint {
    allowMiddlewares(false)
  }

  /// Enables debug logging for this endpoint.
  func debug(_ value: Bool = true) -> Endpoint {
    var copy = self
    copy.debugRequest = value
    return copy
  }

  /// Sets the retry policy for this endpoint.
  func retry(_ policy: RetryPolicy) -> Endpoint {
    var copy = self
    copy.retryPolicy = policy
    return copy
  }

  /// Disables retries for this endpoint.
  func noRetry() -> Endpoint {
    retry(NoRetryPolicy())
  }
}
