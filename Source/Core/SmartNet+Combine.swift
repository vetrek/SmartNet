//
//  SmartNet+Combine.swift
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

// MARK: - Networking Combine

public extension SmartNet {
    
    /// Create a request and convert the reponse `Data` to a `Decodable` object
    /// - Parameters:
    ///   - endpoint: The service `Endpoint`
    ///   - decoder: Json Decoder
    /// - Returns: Return a `Publisher` containing the **Object** response
    func request<D, E>(
        with endpoint: E,
        decoder: JSONDecoder = .default
    ) -> AnyPublisher<D, NetworkError> where D: Decodable, D == E.Response, E: Requestable {
        guard let session = session else {
            return AnyPublisher(Fail<D, NetworkError>(error: NetworkError.invalidSessions))
        }
        
        guard let request = try? endpoint.urlRequest(with: config) else {
            return AnyPublisher(Fail<D, NetworkError>(error: NetworkError.urlGeneration))
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { output in
                // throw an error if response is nil
                guard output.response is HTTPURLResponse else {
                    throw NetworkError.networkFailure
                }
                guard !output.data.isEmpty else {
                    throw NetworkError.emptyResponse
                }
                return output.data
            }
            .decode(type: D.self, decoder: decoder)
            .mapError { error in
                self.resolve(error: error)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Create a request and get the reponse `Data`
    /// - Parameters:
    ///   - endpoint: The service `Endpoint`
    /// - Returns: Return a `Publisher` containing the **Data** response
    func request<E>(
        with endpoint: E
    ) -> AnyPublisher<E.Response, NetworkError>? where E: Requestable, E.Response == Data {
        guard
            let request = try? endpoint.urlRequest(with: config)
        else {
            return AnyPublisher(
                Fail<E.Response, NetworkError>(error: NetworkError.urlGeneration)
            )
        }
        
        return session?.dataTaskPublisher(for: request)
            .tryMap { output in
                // throw an error if response is nil
                guard output.response is HTTPURLResponse else {
                    throw NetworkError.networkFailure
                }
                guard !output.data.isEmpty else {
                    throw NetworkError.emptyResponse
                }
                return output.data
            }
            .mapError { error in
                self.resolve(error: error)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Create a request and convert the reponse `Data` to `String`
    /// - Parameters:
    ///   - endpoint: The service `Endpoint`
    /// - Returns: Return a `Publisher` containing the **String** response
    func request<E>(
        with endpoint: E
    ) -> AnyPublisher<E.Response, NetworkError>? where E: Requestable, E.Response == String {
        guard
            let request = try? endpoint.urlRequest(with: config)
        else {
            return AnyPublisher(
                Fail<E.Response, NetworkError>(error: NetworkError.urlGeneration)
            )
        }
        
        return session?.dataTaskPublisher(for: request)
            .tryMap { output in
                // throw an error if response is nil
                guard output.response is HTTPURLResponse else {
                    throw NetworkError.networkFailure
                }
                guard !output.data.isEmpty else {
                    throw NetworkError.emptyResponse
                }
                
                guard let string = String(data: output.data, encoding: .utf8) else {
                    throw NetworkError.dataToStringFailure(data: output.data)
                }
                
                return string
            }
            .mapError { error in
                self.resolve(error: error)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Create a request which ignore the response `Data`
    /// - Parameters:
    ///   - endpoint: The service `Endpoint`
    /// - Returns: Return a `Publisher` containing **Void**
    func request<E>(
        with endpoint: E
    ) -> AnyPublisher<E.Response, NetworkError>? where E: Requestable, E.Response == Void {
        guard
            let request = try? endpoint.urlRequest(with: config)
        else {
            return AnyPublisher(
                Fail<E.Response, NetworkError>(error: NetworkError.urlGeneration)
            )
        }
        
        return session?.dataTaskPublisher(for: request)
            .tryMap { output in
                // throw an error if response is nil
                guard output.response is HTTPURLResponse else {
                    throw NetworkError.networkFailure
                }
                guard !output.data.isEmpty else {
                    throw NetworkError.emptyResponse
                }
                return ()
            }
            .mapError { error in
                self.resolve(error: error)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
}
