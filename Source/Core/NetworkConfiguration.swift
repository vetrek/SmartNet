//
//  SmartNet.swift
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
    var trustedDomains: [String] { get set }
    var requestTimeout: TimeInterval { get set }
    var printCurl: Bool { get set }
}

/// Service Network default configuration
public final class NetworkConfiguration: NetworkConfigurable {
    /// Service base URL
    public var baseURL: URL

    /// Default HTTPRequest Headers
    public var headers: [String: String] = [:]

    /// Default HTTPRequest query parameters
    public var queryParameters: [String: String] = [:]

    /// Unsecure trusted domains
    public var trustedDomains: [String]

    /// Default HTTPRequest timeout
    public var requestTimeout: TimeInterval
    
    /// Usefull when debugging 
    public var printCurl: Bool

    public init(
        baseURL: URL,
        headers: [String: String] = [:],
        queryParameters: [String: String] = [:],
        trustedDomains: [String] = [],
        requestTimeout: TimeInterval = 60,
        printCurl: Bool = true
    ) {
        self.baseURL = baseURL
        self.headers = headers
        self.queryParameters = queryParameters
        self.trustedDomains = trustedDomains
        self.requestTimeout = requestTimeout
        self.printCurl = printCurl
    }
}
