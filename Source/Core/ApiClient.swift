//
//  ApiClient.swift
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

public typealias PreRequestMiddlewareClosure = (URLRequest) throws -> Void
public typealias PostResponseMiddlewareClosure = (Data?, URLResponse?, Error?) async throws -> ApiClient.Middleware.PostRequestResult

public protocol NetworkCancellable {
  func cancel()
}

extension URLSessionTask: NetworkCancellable { }

public typealias CompletionHandler<T> = (Response<T>) -> Void

public final class ApiClient: NSObject {
  
  /// Network Session Configuration
  @ThreadSafe
  public private(set) var config: NetworkConfigurable
  
  /// Session
  private(set) var session: URLSession?
  
  // MARK: - Internal properties
  
  var downloadsTasks: Set<DownloadTask> = []
  
  var pendingDownloads: [DownloadTask] = []
  
  var uploadsTasks = Set<AnyProgressiveTransferTask>()
  
  var pendingUploads = [AnyProgressiveTransferTask]()
  
  let maxConcurrentDownloads = 6
  
  let maxConcurrentUploads = 6_000_0000
  
  let downloadQueue = DispatchQueue(label: "com.smartnet.downloadQueue")
  let uploadQueue = DispatchQueue(label: "com.smartnet.uploadQueue")
  
  var middlewares: [Middleware] = []
  
  public init(config: NetworkConfigurable) {
    self.config = config
    super.init()
    
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.shouldUseExtendedBackgroundIdleMode = true
    sessionConfig.timeoutIntervalForRequest = config.requestTimeout
    
    self.session = URLSession(
      configuration: sessionConfig,
      delegate: self,
      delegateQueue: .main
    )
  }
  
  /// Prevent Retain cycle problem while using the URLSession delegate = self
  public func destroy() {
    downloadsTasks.forEach { $0.task.cancel() }
    downloadsTasks.removeAll()
    session = nil
  }
  
}

// MARK: - Public Utility Methods

public extension ApiClient {
  
  // MARK: - Network configuration Headers utility
  
  func updateHeaders(_ headers: [String: String]) {
    config.headers.merge(headers) { $1 }
  }
  
  func setHeaders(_ headers: [String: String]) {
    config.headers = headers
  }
  
  func cleanHeaders() {
    config.headers = [:]
  }
  
  func removeHeaders(keys: [String]) {
    keys.forEach { config.headers.removeValue(forKey: $0) }
  }
  
  /// Registers a middleware to intercept and modify requests and responses based on a specific URL path component.
  ///
  /// A URL path component is a segment of the URL that follows the domain name, separated by "/". For instance, in "https://example.com/v1/user", the segments "v1" and "user" are path components.
  ///
  /// Specifying the path component as "/" allows the middleware to intercept every API call, applying global modifications or behaviors. This feature facilitates the application of diverse middleware logic on a per-path-segment basis, enabling precise control over request and response handling for different API endpoints.
  ///
  /// It's possible to associate multiple middleware with the same path component. They execute sequentially in the order they were added, enabling layered modifications or behaviors for the same URL path segment.
  ///
  /// Use this function to attach middleware for intercepting requests matching a specific URL path component. The middleware can perform various operations such as modifying requests before they're sent or processing responses after they're received.
  ///
  /// - Parameters:
  ///   - middleware: The `Middleware` instance encapsulating the path component target, pre-request callback, and post-response callback.
  ///
  /// - Example:
  ///   ```
  ///   let userPreRequestMiddleware = Middleware(pathComponent: "user", preRequestCallbak: { request in
  ///       // Modify the request, e.g., add a specific header
  ///       var headers = request.allHTTPHeaderFields ?? [:]
  ///       headers["Authorization"] = "Bearer token"
  ///       request.allHTTPHeaderFields = headers
  ///   }, postResponseCallbak: { response in
  ///       // Process the response, e.g., logging or error handling
  ///   })
  ///
  ///   apiClient.addMiddleware(userPreRequestMiddleware)
  ///
  ///   let globalMiddleware = Middleware(pathComponent: "/", preRequestCallbak: { request in
  ///       // Applies to every API call
  ///       var headers = request.allHTTPHeaderFields ?? [:]
  ///       headers["App-Version"] = "1.0.0"
  ///       request.allHTTPHeaderFields = headers
  ///   }, postResponseCallbak: { response in
  ///       // Global response handling
  ///   })
  ///
  ///   apiClient.addMiddleware(globalMiddleware)
  ///   ```
  func addMiddleware(_ middleware: Middleware) {
    middlewares.append(middleware)
  }
  
  /// Removes all middlewares for a specific path component.
  ///
  /// Use this method to remove any middleware associated with a specific URL path component.
  /// - Parameter component: The URL path component for which all associated middlewares should be removed.
  ///
  /// - Example:
  ///   ```
  ///   removeMiddleware(for: "user")
  ///   ```
  func removeMiddleware(for component: String) {
    middlewares.removeAll { $0.pathComponent == component }
  }
  
  /// Removes a specific middleware from the list of registered middlewares.
  ///
  /// If you want to stop a middleware from being executed on subsequent requests, you should remove it using this method.
  /// Remember that removing a middleware will not affect the requests that are already in flight.
  ///
  /// - Parameter middleware: The middleware instance that you want to remove.
  ///
  /// - Example:
  ///   ```
  ///   let middleware = apiClient.addMiddleware(component: "/") { request in
  ///     // This will be applied to every API call
  ///   }
  ///   // Later in the code, if you decide to remove the middleware:
  ///   apiClient.removeMiddleware(middleware)
  ///   ```
  func removeMiddleware(_ middleware: Middleware) {
    middlewares.removeAll { $0.uid == middleware.uid }
  }

}

// MARK: - Errors Handlers

extension ApiClient {
  /// Convert Error to `NetworkError`
  /// - Parameter error: Error
  /// - Returns: NetworkError
  func resolve(error: Error) -> NetworkError {
    guard
      (error as? NetworkError) == nil
    else { return (error as! NetworkError) }
    
    let code = URLError.Code(rawValue: (error as NSError).code)
    switch code {
    case .notConnectedToInternet:
      return .networkFailure
    case .cancelled:
      return .cancelled
    default:
      return .generic(error)
    }
  }
  
  /// Check if the Response contains any error
  /// - Parameters:
  ///   - data: Response data
  ///   - response: Response
  ///   - requestError: Response Error
  /// - Returns: NetworlError
  func getRequestError(
    data: Data?,
    response: URLResponse?,
    requestError: Error
  ) -> NetworkError {
    if let statusCode = response?.httpStatusCode {
      return .error(statusCode: statusCode, data: data)
    } else {
      return self.resolve(error: requestError)
    }
  }
  
  func validate(response: URLResponse, data: Data?) -> NetworkError? {
    guard
      let httpResponse = response as? HTTPURLResponse,
      !(200..<300).contains(httpResponse.statusCode)
    else { return nil }
    return .error(statusCode: httpResponse.statusCode, data: data)
  }
}

// MARK: - URLSessionDelegate

extension ApiClient: URLSessionDelegate {
  /// Allow Trusted Domains.
  public func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    // 1. The challenge type is server trust, and not some other kind of challenge.
    // 2. Makes sure the protection space’s host is within the trusted domains
    let protectionSpace = challenge.protectionSpace
    guard
      protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
      config.trustedDomains.contains(where: { $0 == challenge.protectionSpace.host })
    else {
      completionHandler(.performDefaultHandling, nil)
      return
    }
    
    // Evaluate the Credential in the Challenge
    guard
      let serverTrust = protectionSpace.serverTrust
    else {
      completionHandler(.performDefaultHandling, nil)
      return
    }
    
    let credential = URLCredential(trust: serverTrust)
    completionHandler(.useCredential, credential)
    
  }
}

extension URLResponse {
  var httpStatusCode: Int? {
    (self as? HTTPURLResponse)?.statusCode
  }
}

extension ApiClient {
  /// Represents a middleware component that can be applied to network requests and responses.
  /// This struct defines a middleware with a unique identifier, target URL path component,
  /// a callback closure to execute, and specifies whether it should be applied before the request is sent
  /// or after the response is received.
  public struct Middleware {
    
    public enum PostRequestResult {
      case next
      case retryRequest
    }
    
    let uid = UUID()
    
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
    public let preRequestCallbak: PreRequestMiddlewareClosure
    
    /// Closure to be executed after the response is received.
    public let postResponseCallbak: PostResponseMiddlewareClosure
    
    public init(
      pathComponent: String,
      preRequestCallbak: @escaping PreRequestMiddlewareClosure,
      postResponseCallbak: @escaping PostResponseMiddlewareClosure
    ) {
      self.pathComponent = pathComponent
      self.preRequestCallbak = preRequestCallbak
      self.postResponseCallbak = postResponseCallbak
    }
  }
}
