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

public typealias RequestMiddlewareClosure = (URLRequest) throws -> Void

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
  
  var requestMiddlewares = [Middleware]()
  
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
  
  /// Adds a middleware for a specific path component of a URL.
  ///
  /// Path components are the segments in the URL after the domain, separated by "/". For example, in the URL "https://example.com/v1/user", the path components are "v1" and "user".
  /// If you specify the path component as "/", the middleware will be applied to every API call, regardless of its specific path.
  ///
  /// Multiple middlewares can be added for the same path component and they will be executed in the order they were added. This allows for layering different behaviors or modifications to a request based on different conditions or logic.
  ///
  /// Use this method to add a middleware that will be executed for requests with a specific URL path component.
  /// - Parameters:
  ///   - component: The URL path component for which the middleware should be applied.
  ///   - middleware: The middleware closure that will be invoked for requests with the matching path component.
  ///
  /// - Example:
  ///   ```
  ///   apiClient.addMiddleware(component: "user") { request in
  ///       // Modify the request, e.g., add a specific header
  ///       var headers = request.allHTTPHeaderFields ?? [:]
  ///       headers["Custom-Header"] = "CustomValue"
  ///       request.allHTTPHeaderFields = headers
  ///   }
  ///   apiClient.addMiddleware(component: "user") { request in
  ///       // Another middleware for "user", perhaps adding another header or logging
  ///       // This will be executed after the previous "user" middleware
  ///   }
  ///   apiClient.addMiddleware(component: "/") { request in
  ///       // This will be applied to every API call
  ///   }
  ///   ```
  @discardableResult
  func addMiddleware(component: String, callback: @escaping RequestMiddlewareClosure) -> Middleware {
    let middleware = Middleware(pathComponent: component, callback: callback)
    requestMiddlewares.append(middleware)
    return middleware
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
    requestMiddlewares.removeAll { $0.pathComponent == component }
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
    requestMiddlewares.removeAll { $0.uid == middleware.uid }
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
  public struct Middleware {
    let uid = UUID()
    public let pathComponent: String
    public let callback: RequestMiddlewareClosure
  }
}
