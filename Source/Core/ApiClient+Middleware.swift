//
//  SmartNet
//

import Foundation

extension ApiClient {
  /// Represents a middleware component that can be applied to network requests and responses.
  /// This struct defines a middleware with a unique identifier, target URL path component,
  /// a callback closure to execute, and specifies whether it should be applied before the request is sent
  /// or after the response is received.
  public struct Middleware: MiddlewareProtocol {

    public enum PostRequestResult {
      case next
      case retryRequest
    }
    
    public let id = UUID()

    /// Path components are the segments in the URL after the domain, separated by "/". For example, in the URL "https://example.com/v1/user", the path components are "v1" and "user".
    /// If you specify the path component as "/", the middleware will be applied to every API call, regardless of its specific path.
    ///
    /// Examples:
    /// - If `pathComponent` is "user", the middleware is applied only to requests
    ///   that include "/user" in their URL path, such as "https://example.com/api/user" or "https://example.com/api/user/details".
    ///
    /// - If `pathComponent` is "/v1", the middleware targets requests with "/v1" in their path,
    ///   like "https://example.com/api/v1/products" or "https://example.com/api/v1/users/123".
    ///
    /// - Using "/" as `pathComponent` means the middleware applies to every request, regardless of its path.
    ///   This is useful for applying global behaviors, such as logging all requests or adding common headers
    ///   to every request made by the application.
    ///
    /// This targeted application makes it possible to layer middleware based on URL structure, enabling
    /// fine-grained control over request modification and response handling based on specific endpoints or services.
    public let pathComponent: String
    
    /// Closure to be executed before the request is sent.
    let preRequestCallback: (URLRequest) throws -> Void

    /// Closure to be executed after the response is received.
    let postResponseCallback: (Data?, URLResponse?, Error?) async throws -> ApiClient.Middleware.PostRequestResult

    public init(
      pathComponent: String,
      preRequestCallback: @escaping (URLRequest) throws -> Void,
      postResponseCallback: @escaping (Data?, URLResponse?, Error?) async throws -> ApiClient.Middleware.PostRequestResult
    ) {
      self.pathComponent = pathComponent
      self.preRequestCallback = preRequestCallback
      self.postResponseCallback = postResponseCallback
    }

    public func preRequest(_ request: inout URLRequest) throws {
      try preRequestCallback(request)
    }

    public func postResponse(data: Data?, response: URLResponse?, error: Error?) async throws -> PostRequestResult {
      try await postResponseCallback(data, response, error)
    }
  }
}

public protocol MiddlewareProtocol {
  var id: UUID { get }
  var pathComponent: String { get }
  func preRequest(_ request: inout URLRequest) throws
  func postResponse(data: Data?, response: URLResponse?, error: Error?) async throws -> ApiClient.Middleware.PostRequestResult
}
