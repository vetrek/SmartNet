//
//  Endpoint.swift
//  SmartNet
//
//  Created by Valerio Sebastianelli on 7/19/21.
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

        let endpoint = (isFullPath ?
                            path :
                            baseURL.appending(finalPath))
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
    public func urlRequest(
        with config: NetworkConfigurable
    ) throws -> URLRequest {

        let url = try self.url(with: config)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue

        // Always Add the user defined headers
        var allHeaders = headers

        if !useEndpointHeaderOnly {
            // Add the network configuration headers, but do not override current values
            allHeaders.merge(config.headers) { (current, _) in current }
        }

        // Set the HttpRequest headers
        urlRequest.allHTTPHeaderFields = allHeaders

        // Set the HttpRequest Body only if the Request is not a GET
        guard method != .get else { return urlRequest }

        // Set HttpRequest Body based on the bodyEncoding
        urlRequest.httpBody = body?.data

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
    }

}
