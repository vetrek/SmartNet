//
//  File.swift
//  
//
//  Created by Valerio Sebastianelli on 12/4/21.
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
