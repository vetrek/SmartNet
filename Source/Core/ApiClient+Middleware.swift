//
//  SmartNet
//

import Foundation

extension ApiClient {
  /// Represents a middleware component that can be applied to network requests and responses.
  /// This struct defines a middleware with a unique identifier, target URL path matcher,
  /// a callback closure to execute, and specifies whether it should be applied before the request is sent
  /// or after the response is received.
  public struct Middleware: MiddlewareProtocol, Sendable {
    public let id = UUID()

    /// The path matcher that determines which requests this middleware applies to.
    ///
    /// Examples:
    /// - `PathMatcher.contains("user")` - applies to requests with "/user" in their path
    /// - `PathMatcher.contains("/")` - applies to every request (global middleware)
    ///
    /// This targeted application makes it possible to layer middleware based on URL structure, enabling
    /// fine-grained control over request modification and response handling based on specific endpoints or services.
    private let _pathMatcher: PathMatcher

    public var pathMatcher: PathMatcher { _pathMatcher }

    /// Path components are the segments in the URL after the domain, separated by "/". For example, in the URL "https://example.com/v1/user", the path components are "v1" and "user".
    /// If you specify the path component as "/", the middleware will be applied to every API call, regardless of its specific path.
    ///
    /// - Note: Deprecated. Use `pathMatcher.pattern` instead.
    @available(*, deprecated, message: "Use pathMatcher.pattern instead")
    public var pathComponent: String { _pathMatcher.pattern }

    /// Closure to be executed before the request is sent.
    let preRequestCallback: @Sendable (URLRequest) throws -> Void

    /// Closure to be executed after the response is received.
    let postResponseCallback: @Sendable (Data?, URLResponse?, Error?) async throws -> MiddlewarePostRequestResult

    /// Creates a middleware that targets requests matching the specified path matcher.
    ///
    /// - Parameters:
    ///   - pathMatcher: The matcher that determines which requests this middleware applies to.
    ///   - preRequestCallback: Closure executed before the request is sent.
    ///   - postResponseCallback: Closure executed after the response is received.
    public init(
      pathMatcher: PathMatcher,
      preRequestCallback: @Sendable @escaping (URLRequest) throws -> Void,
      postResponseCallback: @Sendable @escaping (Data?, URLResponse?, Error?) async throws -> MiddlewarePostRequestResult
    ) {
      self._pathMatcher = pathMatcher
      self.preRequestCallback = preRequestCallback
      self.postResponseCallback = postResponseCallback
    }

    /// Creates a middleware that targets requests containing the specified path component.
    ///
    /// This initializer maintains backward compatibility with existing code.
    ///
    /// - Parameters:
    ///   - pathComponent: The path component to match. Use "/" for global middleware.
    ///   - preRequestCallback: Closure executed before the request is sent.
    ///   - postResponseCallback: Closure executed after the response is received.
    public init(
      pathComponent: String,
      preRequestCallback: @Sendable @escaping (URLRequest) throws -> Void,
      postResponseCallback: @Sendable @escaping (Data?, URLResponse?, Error?) async throws -> MiddlewarePostRequestResult
    ) {
      self._pathMatcher = ContainsPathMatcher(pattern: pathComponent)
      self.preRequestCallback = preRequestCallback
      self.postResponseCallback = postResponseCallback
    }

    public func preRequest(_ request: inout URLRequest) throws {
      try preRequestCallback(request)
    }

    public func postResponse(data: Data?, response: URLResponse?, error: Error?) async throws -> MiddlewarePostRequestResult {
      try await postResponseCallback(data, response, error)
    }
  }

  public enum MiddlewarePostRequestResult {
    case next
    case retryRequest
  }
}

public protocol MiddlewareProtocol: Sendable {
  var id: UUID { get }

  /// The path component used for matching. Deprecated in favor of `pathMatcher`.
  @available(*, deprecated, message: "Use pathMatcher.pattern instead")
  var pathComponent: String { get }

  /// The path matcher that determines which requests this middleware applies to.
  var pathMatcher: PathMatcher { get }

  func preRequest(_ request: inout URLRequest) throws
  func postResponse(data: Data?, response: URLResponse?, error: Error?) async throws -> ApiClient.MiddlewarePostRequestResult
}

// MARK: - Default Implementation for backward compatibility
public extension MiddlewareProtocol {
  /// Default implementation that creates a ContainsPathMatcher from pathComponent.
  /// This ensures backward compatibility with existing middleware implementations.
  var pathMatcher: PathMatcher {
    ContainsPathMatcher(pattern: pathComponent)
  }
}
