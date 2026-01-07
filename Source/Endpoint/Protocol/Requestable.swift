//
//  Requestable.swift
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

public enum HTTPMethod: String {
  case options = "OPTIONS"
  case get     = "GET"
  case head    = "HEAD"
  case post    = "POST"
  case put     = "PUT"
  case patch   = "PATCH"
  case delete  = "DELETE"
  case trace   = "TRACE"
  case connect = "CONNECT"
}

public enum BodyEncoding: Sendable {
  case json(encoder: JSONEncoder = JSONEncoder())
  case formUrlEncodedAscii
  case plainText
}

// MARK: - HTTPPayload

/// Represents the payload/body of an HTTP request.
///
/// Use this enum to specify the content sent with POST, PUT, PATCH requests.
///
/// Example usage:
/// ```swift
/// // JSON body from dictionary
/// let payload: HTTPPayload = .json(["name": "John", "age": 30])
///
/// // JSON body from Encodable
/// let payload: HTTPPayload = .encodable(user)
///
/// // Multipart form data
/// let payload: HTTPPayload = .multipart(formData)
///
/// // Raw data
/// let payload: HTTPPayload = .raw(data, contentType: "application/octet-stream")
/// ```
public enum HTTPPayload {
  /// JSON-encoded body from a dictionary
  case json(_ dictionary: [String: Any], encoding: BodyEncoding = .json())

  /// JSON-encoded body from an Encodable value
  case encodable(_ value: any Encodable, encoder: JSONEncoder = JSONEncoder())

  /// Form URL-encoded body
  case formUrlEncoded(_ dictionary: [String: Any])

  /// Multipart form data for file uploads
  case multipart(_ form: MultipartFormData)

  /// Raw data with custom content type
  case raw(_ data: Data, contentType: String)

  /// Plain text body
  case text(_ string: String)

  /// Converts to HTTPBody for backwards compatibility
  var asHTTPBody: HTTPBody? {
    switch self {
    case .json(let dictionary, let encoding):
      return HTTPBody(dictionary: dictionary, bodyEncoding: encoding)
    case .encodable(let value, let encoder):
      return HTTPBody(encodable: value, bodyEncoding: .json(encoder: encoder))
    case .formUrlEncoded(let dictionary):
      return HTTPBody(dictionary: dictionary, bodyEncoding: .formUrlEncodedAscii)
    case .text(let string):
      return HTTPBody(string: string)
    case .raw:
      // Raw data doesn't have a direct HTTPBody conversion
      return nil
    case .multipart:
      // Multipart is handled separately
      return nil
    }
  }

  /// Returns the multipart form data if this is a multipart payload
  var asMultipartForm: MultipartFormData? {
    if case .multipart(let form) = self {
      return form
    }
    return nil
  }

  /// Returns raw data and content type if this is a raw payload
  var asRawData: (data: Data, contentType: String)? {
    if case .raw(let data, let contentType) = self {
      return (data, contentType)
    }
    return nil
  }
}

public protocol Requestable {
  associatedtype Response

  /// HTTPRequest service path
  var path: String { get }

  /// The specified `path` is the a complete URL
  var isFullPath: Bool { get }

  /// HTTPRequest method
  var method: HTTPMethod { get }

  /// HTTPRequest headers
  var headers: [String: String] { get }

  /// Tell the Network to only use the specified headers
  var useEndpointHeaderOnly: Bool { get }

  /// Query parameters
  var queryParameters: QueryParameters? { get }

  /// Body (legacy - prefer using `payload`)
  var body: HTTPBody? { get }

  /// Multipart Form Data Form (legacy - prefer using `payload`)
  var form: MultipartFormData? { get }

  /// The request payload. When set, takes precedence over `body` and `form`.
  var payload: HTTPPayload? { get }

  /// Call
  var allowMiddlewares: Bool { get }

  /// Enables cURL logging for this endpoint regardless of the client's global debug flag.
  var debugRequest: Bool { get }

  /// Custom retry policy for this endpoint. If nil, uses the config's default policy.
  var retryPolicy: RetryPolicy? { get }

  /// Return the `URLRequest` from the Requestable
  func urlRequest(with config: NetworkConfigurable) throws(NetworkError) -> URLRequest
}

extension Requestable {
  /// Create the Request `URL`
  func url(with config: NetworkConfigurable) throws(NetworkError) -> URL {
    let baseURL = config.baseURL.absoluteString.last != "/" ?
      config.baseURL.absoluteString + "/" :
      config.baseURL.absoluteString

    let finalPath = path.first != "/" ?
      path :
      path[1..<path.count]

    let endpoint = isFullPath ?
      path :
      baseURL.appending(finalPath)

    let escapedEndpoint = endpoint.addingPercentEncoding(
      withAllowedCharacters: .urlQueryAllowed
    ) ?? String()

    guard var urlComponents = URLComponents(string: escapedEndpoint) else {
      throw NetworkError.urlGeneration
    }

    var urlQueryItems = urlComponents.queryItems ?? []

    if let queryParameters = queryParameters?.parameters {
      urlQueryItems += queryParameters.map {
        URLQueryItem(name: $0.key, value: "\($0.value)")
      }
    }

    urlQueryItems += config.queryParameters.map {
      URLQueryItem(name: $0.key, value: $0.value)
    }

    urlComponents.queryItems = !urlQueryItems.isEmpty ? urlQueryItems : nil

    guard let url = urlComponents.url else {
      throw NetworkError.urlGeneration
    }
    return url
  }

  /// Creates a `URLRequest` from the endpoint configuration.
  /// - Parameter config: The network configuration
  /// - Returns: A configured `URLRequest`
  public func urlRequest(with config: NetworkConfigurable) throws(NetworkError) -> URLRequest {
    let url = try self.url(with: config)
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = method.rawValue

    // Always add the user defined headers
    var allHeaders = headers

    if !useEndpointHeaderOnly {
      // Add the network configuration headers, but do not override current values
      allHeaders.merge(config.headers) { (current, _) in current }
    }

    // Set the HttpRequest Body only if the Request is not a GET
    guard method != .get else {
      urlRequest.allHTTPHeaderFields = allHeaders
      return urlRequest
    }

    // Handle payload (new API) - takes precedence over body/form
    if let payload = payload {
      switch payload {
      case .json(let dictionary, let encoding):
        if var httpBody = HTTPBody(dictionary: dictionary, bodyEncoding: encoding) {
          switch httpBody.bodyEncoding {
          case .json:
            allHeaders.merge(["Content-Type": "application/json"]) { (current, _) in current }
          case .formUrlEncodedAscii:
            allHeaders.merge(["Content-Type": "application/x-www-form-urlencoded"]) { (current, _) in current }
          case .plainText:
            allHeaders.merge(["Content-Type": "text/plain"]) { (current, _) in current }
          }
          urlRequest.httpBody = httpBody.addingKeyValues(keyValues: config.bodyParameters).data
        }

      case .encodable(let value, let encoder):
        if var httpBody = HTTPBody(encodable: value, bodyEncoding: .json(encoder: encoder)) {
          allHeaders.merge(["Content-Type": "application/json"]) { (current, _) in current }
          urlRequest.httpBody = httpBody.addingKeyValues(keyValues: config.bodyParameters).data
        }

      case .formUrlEncoded(let dictionary):
        if var httpBody = HTTPBody(dictionary: dictionary, bodyEncoding: .formUrlEncodedAscii) {
          allHeaders.merge(["Content-Type": "application/x-www-form-urlencoded"]) { (current, _) in current }
          urlRequest.httpBody = httpBody.addingKeyValues(keyValues: config.bodyParameters).data
        }

      case .multipart(let form):
        allHeaders["Content-Type"] = "multipart/form-data; boundary=\(form.boundary)"
        urlRequest.httpBody = form.data

      case .raw(let data, let contentType):
        allHeaders["Content-Type"] = contentType
        urlRequest.httpBody = data

      case .text(let string):
        allHeaders.merge(["Content-Type": "text/plain"]) { (current, _) in current }
        urlRequest.httpBody = string.data(using: .utf8)
      }
    }
    // Handle legacy body property
    else if var body = body {
      switch body.bodyEncoding {
      case .json:
        allHeaders.merge(["Content-Type": "application/json"]) { (current, _) in current }
      case .formUrlEncodedAscii:
        allHeaders.merge(["Content-Type": "application/x-www-form-urlencoded"]) { (current, _) in current }
      case .plainText:
        allHeaders.merge(["Content-Type": "text/plain"]) { (current, _) in current }
      }

      switch body.bodyType {
      case .keyValue:
        urlRequest.httpBody = body.addingKeyValues(keyValues: config.bodyParameters).data
      case .string:
        urlRequest.httpBody = body.data
      }
    }
    // Handle legacy form property
    else if let form = form {
      allHeaders["Content-Type"] = "multipart/form-data; boundary=\(form.boundary)"
      urlRequest.httpBody = form.data
    }
    // Fall back to config body parameters
    else if let body = HTTPBody(dictionary: config.bodyParameters)?.data {
      allHeaders.merge(["Content-Type": "application/json"]) { (current, _) in current }
      urlRequest.httpBody = body
    }

    urlRequest.allHTTPHeaderFields = allHeaders
    return urlRequest
  }
}

public extension Requestable {
  var debugRequest: Bool { false }
  var retryPolicy: RetryPolicy? { nil }
  var payload: HTTPPayload? { nil }
}
