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

enum RequestGenerationError: Error {
    case components
}

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

public enum BodyEncoding {
    case json
    case formUrlEncodedAscii
    case plainText
    case multiPartFormData
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

    /// Body
    var body: HTTPBody? { get }
    
    /// Multipart Form Data Form
    var form: MultipartFormData? { get }

    /// Return the `URLRequest` from the Requestable
    func urlRequest(with config: NetworkConfigurable) throws -> URLRequest
}

extension Requestable {
    /// Create the Request `URL`
    func url(with config: NetworkConfigurable) throws -> URL {

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

        guard
            var urlComponents = URLComponents(string: escapedEndpoint)
        else { throw RequestGenerationError.components }

        var urlQueryItems = [URLQueryItem]()

        if let queryParameters = queryParameters?.parameters {
            urlQueryItems += queryParameters.map {
                URLQueryItem(name: $0.key, value: "\($0.value)")
            }
        }

        urlQueryItems += config.queryParameters.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }

        urlComponents.queryItems = !urlQueryItems.isEmpty ? urlQueryItems : nil

        guard let url = urlComponents.url else { throw RequestGenerationError.components }
        return url
    }

    /// Crea l'oggetto `URLRequest` per la chiamata al servizio
    /// - Parameter config: La `USCNetworkConfigurable` di `USCNetwork`
    /// - Returns: Oggetto `URLRequest`
    public func urlRequest(with config: NetworkConfigurable) throws -> URLRequest {

        let url = try self.url(with: config)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue

        // Always Add the user defined headers
        var allHeaders = headers

        if !useEndpointHeaderOnly {
            // Add the network configuration headers, but do not override current values
            allHeaders.merge(config.headers) { (current, _) in current }
        }
        
        if let form = form {
            // Make sure this header is always set for multipart form  data uploads
            allHeaders["Content-Type"] = "multipart/form-data; boundary=\(form.boundary)"
        }

        // Set the HttpRequest headers
        urlRequest.allHTTPHeaderFields = allHeaders

        // Set the HttpRequest Body only if the Request is not a GET
        guard method != .get else { return urlRequest }

        // Set HttpRequest Body based on the bodyEncoding
        urlRequest.httpBody = body?.data ?? form?.data

        return urlRequest
    }

}

public struct Endpoint<Value>: Requestable {
    
    public typealias Response = Value

    public var path: String
    public var isFullPath: Bool
    public var method: HTTPMethod
    public var headers: [String: String]
    public var useEndpointHeaderOnly: Bool
    public var queryParameters: QueryParameters?
    public var body: HTTPBody?
    public var form: MultipartFormData?

    public init(
        path: String,
        isFullPath: Bool = false,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        useEndpointHeaderOnly: Bool = false,
        queryParameters: QueryParameters? = nil,
        body: HTTPBody? = nil
    ) {
        self.path = path
        self.isFullPath = isFullPath
        self.method = method
        self.headers = headers
        self.useEndpointHeaderOnly = useEndpointHeaderOnly
        self.queryParameters = queryParameters
        self.body = body
        self.form = nil
    }
    
    public init(
        path: String,
        isFullPath: Bool = false,
        headers: [String: String] = [:],
        useEndpointHeaderOnly: Bool = false,
        queryParameters: QueryParameters? = nil,
        form: MultipartFormData
    ) {
        self.path = path
        self.isFullPath = isFullPath
        self.method = .post
        self.headers = headers
        self.useEndpointHeaderOnly = useEndpointHeaderOnly
        self.queryParameters = queryParameters
        self.body = nil
        self.form = form
    }

}

public struct DownloadEndpoint: Requestable {
    public typealias Response = Void
    
    public var path: String
    public var isFullPath: Bool
    public var method: HTTPMethod
    public var headers: [String: String]
    public var useEndpointHeaderOnly: Bool
    public var queryParameters: QueryParameters?
    public let body: HTTPBody?
    public let form: MultipartFormData?
    
    public init(
        path: String,
        isFullPath: Bool = false,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        useEndpointHeaderOnly: Bool = false,
        queryParameters: QueryParameters? = nil
    ) {
        self.path = path
        self.isFullPath = isFullPath
        self.method = method
        self.headers = headers
        self.useEndpointHeaderOnly = useEndpointHeaderOnly
        self.queryParameters = queryParameters
        self.body = nil
        self.form = nil
    }
}
