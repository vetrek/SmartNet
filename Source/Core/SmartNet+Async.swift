//
//  SmartNet+Async.swift
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

public extension SmartNet {
    func request<D, E>(
        with endpoint: E,
        decoder: JSONDecoder = .default,
        progressHUD: SNProgressHUD? = nil
    ) async throws -> E.Response where D : Decodable, D == E.Response, E : Requestable {
        let data = try await dataRequest(endpoint: endpoint, progressHUD: progressHUD)
        guard let responseObject = try? decoder.decode(D.self, from: data) else {
            throw NetworkError.parsingFailed
        }
        return responseObject
    }
    
    func request<E>(
        with endpoint: E,
        progressHUD: SNProgressHUD? = nil
    ) async throws -> E.Response where E : Requestable, E.Response == Data {
        try await dataRequest(endpoint: endpoint, progressHUD: progressHUD)
    }
    
    func request<E>(
        with endpoint: E,
        progressHUD: SNProgressHUD? = nil
    ) async throws -> E.Response where E : Requestable, E.Response == String {
        let data = try await dataRequest(endpoint: endpoint, progressHUD: progressHUD)
        guard let string = String(data: data, encoding: .utf8) else {
            throw NetworkError.dataToStringFailure(data: data)
        }
        return string
    }
    
    @discardableResult
    func request<E>(
        with endpoint: E,
        progressHUD: SNProgressHUD? = nil
    ) async throws -> E.Response where E : Requestable, E.Response == Void {
        let _ = try await dataRequest(endpoint: endpoint, progressHUD: progressHUD)
        return
    }
    
    private func dataRequest<E>(
        endpoint: E,
        progressHUD: SNProgressHUD? = nil
    ) async throws -> Data where E : Requestable {
        return try await withCheckedThrowingContinuation { continuation in
            dataRequest(with: endpoint, progressHUD: progressHUD) { response in
                switch response.result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
