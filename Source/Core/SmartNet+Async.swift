//
//  File.swift
//  
//
//  Created by Valerio Sebastianelli on 12/4/21.
//

import Foundation

@available(iOS 15.0.0, *)
public extension SmartNet {
    func request<D, E>(
        with endpoint: E,
        decoder: JSONDecoder = .default
    ) async -> Response<E.Response> where D : Decodable, D == E.Response, E : Requestable {
        guard
            let session = session,
            let request = try? endpoint.urlRequest(with: config)
        else {
            return Response(
                result: .failure(.urlGeneration),
                session: session,
                request: nil,
                response: nil
            )
        }
        
        if config.printCurl {
            SmartNet.printCurl(
                session: session,
                request: request
            )
        }
        
        do {
            let (data, response) = try await session.data(for: request, delegate: nil)
            
            if let networkError = validate(response: response, data: data) {
                return Response(
                    result: .failure(networkError),
                    session: self.session,
                    request: request,
                    response: response
                )
            }
            
            guard let responseObject = try? decoder.decode(D.self, from: data)
            else {
                return Response(
                    result: .failure(.parsingFailed),
                    session: self.session,
                    request: request,
                    response: response
                )
            }
            return Response(
                result: .success(responseObject),
                session: self.session,
                request: request,
                response: response
            )
            
        } catch {
            let error = resolve(error: error)
            return Response(
                result: .failure(error),
                session: session,
                request: request,
                response: nil
            )
        }
    }
    
    func request<E>(
        with endpoint: E
    ) async -> Response<E.Response> where E : Requestable, E.Response == Data {
        guard
            let session = session,
            let request = try? endpoint.urlRequest(with: config)
        else {
            return Response(
                result: .failure(.urlGeneration),
                session: session,
                request: nil,
                response: nil
            )
        }
        
        if config.printCurl {
            SmartNet.printCurl(
                session: session,
                request: request
            )
        }
        
        do {
            let (data, response) = try await session.data(for: request, delegate: nil)
            
            if let networkError = validate(response: response, data: data) {
                return Response(
                    result: .failure(networkError),
                    session: self.session,
                    request: request,
                    response: response
                )
            }
            
            return Response(
                result: .success(data),
                session: self.session,
                request: request,
                response: response
            )
            
        } catch {
            let error = resolve(error: error)
            return Response(
                result: .failure(error),
                session: session,
                request: request,
                response: nil
            )
        }
    }
    
    func request<E>(
        with endpoint: E
    ) async -> Response<E.Response> where E : Requestable, E.Response == String {
        guard
            let session = session,
            let request = try? endpoint.urlRequest(with: config)
        else {
            return Response(
                result: .failure(.urlGeneration),
                session: session,
                request: nil,
                response: nil
            )
        }
        
        if config.printCurl {
            SmartNet.printCurl(
                session: session,
                request: request
            )
        }
        
        do {
            let (data, response) = try await session.data(for: request, delegate: nil)
            
            if let networkError = validate(response: response, data: data) {
                return Response(
                    result: .failure(networkError),
                    session: self.session,
                    request: request,
                    response: response
                )
            }
            
            guard let string = String(data: data, encoding: .utf8)
            else {
                return Response(
                    result: .failure(.dataToStringFailure(data: data)),
                    session: self.session,
                    request: request,
                    response: response
                )
            }
            
            return Response(
                result: .success(string),
                session: self.session,
                request: request,
                response: response
            )
            
        } catch {
            let error = resolve(error: error)
            return Response(
                result: .failure(error),
                session: session,
                request: request,
                response: nil
            )
        }
    }
    
    func request<E>(
        with endpoint: E
    ) async -> Response<E.Response> where E : Requestable, E.Response == Void {
        guard
            let session = session,
            let request = try? endpoint.urlRequest(with: config)
        else {
            return Response(
                result: .failure(.urlGeneration),
                session: session,
                request: nil,
                response: nil
            )
        }
        
        if config.printCurl {
            SmartNet.printCurl(
                session: session,
                request: request
            )
        }
        
        do {
            let (data, response) = try await session.data(for: request, delegate: nil)
            
            if let networkError = validate(response: response, data: data) {
                return Response(
                    result: .failure(networkError),
                    session: self.session,
                    request: request,
                    response: response
                )
            }
            
            return Response(
                result: .success(()),
                session: self.session,
                request: request,
                response: response
            )
            
        } catch {
            let error = resolve(error: error)
            return Response(
                result: .failure(error),
                session: session,
                request: request,
                response: nil
            )
        }
    }
}
