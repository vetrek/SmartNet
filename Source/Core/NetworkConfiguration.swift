//
//  NetworkConfiguration.swift
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

public protocol NetworkConfigurable {
  var baseURL: URL { get set }
  var headers: [String: String] { get set }
  var queryParameters: [String: String] { get }
  var bodyParameters: [String: Any] { get }
  var trustedDomains: [String] { get set }
  var requestTimeout: TimeInterval { get set }
  var debug: Bool { get set }
}

/// Service Network default configuration
public final class NetworkConfiguration: NetworkConfigurable {
  /// Service base URL
  public var baseURL: URL
  
  /// Default Request Headers
  public var headers: [String: String] = [:]
  
  /// Default Request query parameters
  public var queryParameters: [String: String] = [:]
  
  /// Defatult Post body parameters
  /// This could be usefull if you need to add the same key/value to the body of each post.
  public var bodyParameters: [String: Any] = [:]
  
  /// Unsecure trusted domains
  public var trustedDomains: [String]
  
  /// Default HTTPRequest timeout
  public var requestTimeout: TimeInterval
  
  /// Print cURL and Response
  public var debug: Bool
  
  public init(
    baseURL: URL,
    headers: [String: String] = [:],
    queryParameters: [String: String] = [:],
    bodyParameters: [String: Any] = [:],
    trustedDomains: [String] = [],
    requestTimeout: TimeInterval = 60,
    debug: Bool = true
  ) {
    self.baseURL = baseURL
    self.headers = headers
    self.queryParameters = queryParameters
    self.bodyParameters = bodyParameters
    self.trustedDomains = trustedDomains
    self.requestTimeout = requestTimeout
    self.debug = debug
  }
}
