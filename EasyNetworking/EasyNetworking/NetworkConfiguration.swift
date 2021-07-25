//
//  EasyNetworkConfiguration.swift
//  EasyNetworking
//
//  Created by Valerio Sebastianelli on 7/19/21.
//

import Foundation

public protocol NetworkConfigurable {
    var baseURL: URL { get set }
    var headers: [String: String] { get set }
    var queryParameters: [String: String] { get }
    var trustedDomains: [String] { get set }
    var requestTimeout: TimeInterval { get set }
}

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
    
    public init(
        baseURL: URL,
        headers: [String: String] = [:],
        queryParameters: [String: String] = [:],
        trustedDomains: [String] = [],
        requestTimeout: TimeInterval = 60
    ) {
        self.baseURL = baseURL
        self.headers = headers
        self.queryParameters = queryParameters
        self.trustedDomains = trustedDomains
        self.requestTimeout = requestTimeout
    }
}
