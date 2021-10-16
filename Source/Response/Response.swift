//
//  File.swift
//  
//
//  Created by Valerio Sebastianelli on 10/16/21.
//

import Foundation

public struct Response<Value> {
    public let result: Result<Value>
    var session: URLSession?
    var request: URLRequest?
    
    public init(result: Result<Value>) {
        self.result = result
        self.session = nil
        self.request = nil
    }
    
    init(result: Result<Value>, session: URLSession?, request: URLRequest?) {
        self.result = result
        self.session = session
        self.request = request
    }
    
    public func printCurl() -> String {
        var components = ["$ curl -v"]
        
        guard
            let session = session,
            let request = self.request,
            let url = request.url,
            let host = url.host
        else {
            return "$ curl command could not be created"
        }
        
        if let httpMethod = request.httpMethod, httpMethod != "GET" {
            components.append("-X \(httpMethod)")
        }
        
        if let credentialStorage = session.configuration.urlCredentialStorage {
            let protectionSpace = URLProtectionSpace(
                host: host,
                port: url.port ?? 0,
                protocol: url.scheme,
                realm: host,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            )
            
            if let credentials = credentialStorage.credentials(for: protectionSpace)?.values {
                for credential in credentials {
                    guard let user = credential.user, let password = credential.password else { continue }
                    components.append("-u \(user):\(password)")
                }
            }
        }
        
        if session.configuration.httpShouldSetCookies {
            if let cookieStorage = session.configuration.httpCookieStorage,
               let cookies = cookieStorage.cookies(for: url), !cookies.isEmpty {
                let string = cookies.reduce("") { $0 + "\($1.name)=\($1.value);" }
                
                components.append("-b \"\(string[..<string.index(before: string.endIndex)])\"")
            }
        }
        
        var headers: [AnyHashable: Any] = [:]
        
        session.configuration.httpAdditionalHeaders?.filter {  $0.0 != AnyHashable("Cookie") }
        .forEach { headers[$0.0] = $0.1 }
        
        request.allHTTPHeaderFields?.filter { $0.0 != "Cookie" }
        .forEach { headers[$0.0] = $0.1 }
        
        components += headers.map {
            let escapedValue = String(describing: $0.value).replacingOccurrences(of: "\"", with: "\\\"")
            
            return "-H \"\($0.key): \(escapedValue)\""
        }
        
        if let httpBodyData = request.httpBody, let httpBody = String(data: httpBodyData, encoding: .utf8) {
            var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"")
            
            components.append("-d \"\(escapedBody)\"")
        }
        
        components.append("\"\(url.absoluteString)\"")
        
        return components.joined(separator: " \\\n\t")
    }
}

