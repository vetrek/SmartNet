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

@available(iOS 15.0.0, *)
public extension SmartNet {
    func request<D, E>(
        with endpoint: E,
        decoder: JSONDecoder = .default,
        progressHUD: SNProgressHUD? = nil
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
        
        if config.debug {
            SmartNet.printCurl(
                session: session,
                request: request
            )
        }
        
        do {
            progressHUD?.show()
            defer { progressHUD?.dismiss() }
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
        with endpoint: E,
        progressHUD: SNProgressHUD? = nil
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
        
        if config.debug {
            SmartNet.printCurl(
                session: session,
                request: request
            )
        }
        
        do {
            progressHUD?.show()
            defer { progressHUD?.dismiss() }
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
        with endpoint: E,
        progressHUD: SNProgressHUD? = nil
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
        
        if config.debug {
            SmartNet.printCurl(
                session: session,
                request: request
            )
        }
        
        do {
            progressHUD?.show()
            defer { progressHUD?.dismiss() }
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
        with endpoint: E,
        progressHUD: SNProgressHUD? = nil
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
        
        if config.debug {
            SmartNet.printCurl(
                session: session,
                request: request
            )
        }
        
        do {
            progressHUD?.show()
            defer { progressHUD?.dismiss() }
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
