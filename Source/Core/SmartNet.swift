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
import Combine

public protocol NetworkCancellable {
    func cancel()
}

extension URLSessionTask: NetworkCancellable { }

public typealias CompletionHandler<T> = (Response<T>) -> Void

public final class SmartNet: NSObject {
    
    /// Network Session Configuration
    public private(set) var config: NetworkConfigurable

    /// Session
    private(set) var session: URLSession?
    
    // MARK: - Internal properties
    
    var downloadsTasks: Set<DownloadTask> = []

    public init(config: NetworkConfigurable) {
        self.config = config
        super.init()

        let sessionConfig = URLSessionConfiguration.default
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

public extension SmartNet {
    
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
}

// MARK: - Errors Handlers

extension SmartNet {
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
        requestError: Error?
    ) -> NetworkError? {
        guard let requestError = requestError else { return nil }
        if let statusCode = response?.statusCode {
            return .error(statusCode: statusCode, data: data)
        } else {
            return self.resolve(error: requestError)
        }
    }
    
    func validate(response: URLResponse, data: Data) -> NetworkError? {
        guard
            let httpResponse = response as? HTTPURLResponse,
            !(200..<300).contains(httpResponse.statusCode)
        else { return nil }
        return .error(statusCode: httpResponse.statusCode, data: data)
    }
}

// MARK: - URLSessionDelegate

extension SmartNet: URLSessionDelegate {
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
    var statusCode: Int? {
        (self as? HTTPURLResponse)?.statusCode
    }
}
