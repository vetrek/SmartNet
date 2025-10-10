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
