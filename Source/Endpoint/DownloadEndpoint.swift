//
//  DownloadEndpoint.swift
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

/// A specialized endpoint for file download operations.
///
/// Use `DownloadEndpoint` when you need to download files from a remote server.
/// This endpoint type conforms to ``Requestable`` with a `Void` response type,
/// as the downloaded file is handled separately through the download API.
///
/// Example:
/// ```swift
/// let endpoint = DownloadEndpoint(path: "/files/document.pdf")
/// let url = try await apiClient.download(endpoint, to: destinationURL)
/// ```
public struct DownloadEndpoint: Requestable {
  public typealias Response = Void
  
  public var path: String
  public var isFullPath: Bool
  public var method: HTTPMethod
  public var headers: [String: String]
  public var useEndpointHeaderOnly: Bool
  public var queryParameters: QueryParameters?
  public let body: HTTPBody? = nil
  public let form: MultipartFormData? = nil
  public var allowMiddlewares: Bool
  public var debugRequest: Bool

  /// Creates a new download endpoint.
  ///
  /// - Parameters:
  ///   - path: The URL path for the download request.
  ///   - isFullPath: If `true`, the path is treated as a complete URL. Default is `false`.
  ///   - method: The HTTP method to use. Default is `.get`.
  ///   - headers: Additional headers to include in the request.
  ///   - useEndpointHeaderOnly: If `true`, only endpoint headers are used, ignoring configuration headers.
  ///   - queryParameters: Optional query parameters to append to the URL.
  ///   - allowMiddlewares: If `true`, middlewares are applied to this request. Default is `true`.
  ///   - debugRequest: If `true`, logs the cURL representation of the request.
  public init(
    path: String,
    isFullPath: Bool = false,
    method: HTTPMethod = .get,
    headers: [String: String] = [:],
    useEndpointHeaderOnly: Bool = false,
    queryParameters: QueryParameters? = nil,
    allowMiddlewares: Bool = true,
    debugRequest: Bool = false
  ) {
    self.path = path
    self.isFullPath = isFullPath
    self.method = method
    self.headers = headers
    self.useEndpointHeaderOnly = useEndpointHeaderOnly
    self.queryParameters = queryParameters
    self.allowMiddlewares = allowMiddlewares
    self.debugRequest = debugRequest
  }
}
