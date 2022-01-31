//
//  SmartNet+Closure.swift
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

// MARK: - Networking Closure

public extension SmartNet {
    
    /// Create a request and convert the reponse `Data` to a `Decodable` object
    /// - Parameters:
    ///   - endpoint: The service `Endpoint`
    ///   - decoder: Json Decoder
    ///   - queue: completiuon DispatchQueue
    ///   - completion: response completion
    /// - Returns: Return a cancellable Network Request
    @discardableResult
    func request<D, E>(
        with endpoint: E,
        decoder: JSONDecoder = .default,
        queue: DispatchQueue = .main,
        progressHUD: SNProgressHUD? = nil,
        completion: @escaping (Response<E.Response>) -> Void
    ) -> NetworkCancellable? where D: Decodable, D == E.Response, E: Requestable {
        guard
            let request = try? endpoint.urlRequest(with: config)
        else {
            completion(
                Response(
                    result: .failure(.urlGeneration),
                    session: session,
                    request: nil,
                    response: nil
                )
            )
            return nil
        }
        
        progressHUD?.show()
        let task = session?.dataTask(
            with: request
        ) { [weak self] (data, response, error) in
            guard let self = self else {
                progressHUD?.dismiss()
                return
            }
            
            queue.async {
                defer { progressHUD?.dismiss() }
                
                if self.config.debug, let session = self.session {
                    SmartNet.printCurl(
                        session: session,
                        request: request,
                        data: data
                    )
                }
                
                if let networkError = self.getRequestError(
                    data: data,
                    response: response,
                    requestError: error
                ) {
                    completion(
                        Response(
                            result: .failure(networkError),
                            session: self.session,
                            request: request,
                            response: response
                        )
                    )
                    return
                }
                
                guard
                    let data = data
                else {
                    completion(
                        Response(
                            result: .failure(.emptyResponse),
                            session: self.session,
                            request: request,
                            response: response
                        )
                    )
                    return
                }
                
                do {
                    let responseObject = try decoder.decode(D.self, from: data)
                    completion(
                        Response(
                            result: .success(responseObject),
                            session: self.session,
                            request: request,
                            response: response
                        )
                    )
                } catch {
                    print(error)
                    completion(
                        Response(
                            result: .failure(.parsingFailed),
                            session: self.session,
                            request: request,
                            response: response
                        )
                    )
                }
            }
        }
        task?.resume()
        return task
    }
    
    /// Create a request which ignore the response `Data`
    /// - Parameters:
    ///   - endpoint: The service `Endpoint`
    ///   - queue: completiuon DispatchQueue
    ///   - completion: response completion
    /// - Returns: Return a cancellable Network Request
    @discardableResult
    func request<E>(
        with endpoint: E,
        queue: DispatchQueue = .main,
        progressHUD: SNProgressHUD? = nil,
        completion: @escaping (Response<E.Response>) -> Void
    ) -> NetworkCancellable? where E: Requestable, E.Response == Data {
        guard
            let request = try? endpoint.urlRequest(with: config)
        else {
            completion(
                Response(
                    result: .failure(.urlGeneration),
                    session: session,
                    request: nil,
                    response: nil
                )
            )
            return nil
        }
        
        progressHUD?.show()
        
        let task = session?.dataTask(
            with: request
        ) { [weak self] (data, response, error) in
            guard let self = self else {
                progressHUD?.dismiss()
                return
            }
            
            queue.async {
                defer { progressHUD?.dismiss() }
                
                if self.config.debug, let session = self.session {
                    SmartNet.printCurl(
                        session: session,
                        request: request,
                        data: data
                    )
                }
                
                if let networkError = self.getRequestError(
                    data: data,
                    response: response,
                    requestError: error
                ) {
                    completion(
                        Response(
                            result: .failure(networkError),
                            session: self.session,
                            request: request,
                            response: response
                        )
                    )
                    return
                }
                
                guard
                    let data = data
                else {
                    completion(
                        Response(
                            result: .failure(.emptyResponse),
                            session: self.session,
                            request: request,
                            response: response
                        )
                    )
                    return
                }
                
                completion(
                    Response(
                        result: .success(data),
                        session: self.session,
                        request: request,
                        response: response
                    )
                )
            }
        }
        task?.resume()
        return task
    }
    
    /// Create a request and convert the reponse `Data` to `String`
    /// - Parameters:
    ///   - endpoint: The service `Endpoint`
    ///   - queue: completiuon DispatchQueue
    ///   - completion: response completion
    /// - Returns: Return a cancellable Network Request
    @discardableResult
    func request<E>(
        with endpoint: E,
        queue: DispatchQueue = .main,
        progressHUD: SNProgressHUD? = nil,
        completion: @escaping (Response<E.Response>) -> Void
    ) -> NetworkCancellable? where E: Requestable, E.Response == String {
        guard
            let request = try? endpoint.urlRequest(with: config)
        else {
            completion(
                Response(
                    result: .failure(.urlGeneration),
                    session: session,
                    request: nil,
                    response: nil
                )
            )
            return nil
        }
        
        progressHUD?.show()
        
        let task = session?.dataTask(
            with: request
        ) { [weak self] (data, response, error) in
            guard let self = self else {
                progressHUD?.dismiss()
                return
            }
            
            queue.async {
                defer { progressHUD?.dismiss() }
                
                if self.config.debug, let session = self.session {
                    SmartNet.printCurl(
                        session: session,
                        request: request,
                        data: data
                    )
                }
                
                if let networkError = self.getRequestError(
                    data: data,
                    response: response,
                    requestError: error
                ) {
                    completion(
                        Response(
                            result: .failure(networkError),
                            session: self.session,
                            request: request,
                            response: response
                        )
                    )
                    return
                }
                
                guard
                    let data = data
                else {
                    completion(
                        Response(
                            result: .failure(.emptyResponse),
                            session: self.session,
                            request: request,
                            response: response
                        )
                    )
                    return
                }
                
                guard
                    let string = String(data: data, encoding: .utf8)
                else {
                    completion(
                        Response(
                            result: .failure(.dataToStringFailure(data: data)),
                            session: self.session,
                            request: request,
                            response: response
                        )
                    )
                    return
                }
                
                completion(
                    Response(
                        result: .success(string),
                        session: self.session,
                        request: request,
                        response: response
                    )
                )
            }
        }
        task?.resume()
        return task
    }
    
    /// Create a request which ignore the response `Data`
    /// - Parameters:
    ///   - endpoint: The service `Endpoint`
    ///   - queue: completiuon DispatchQueue
    ///   - completion: response completion
    /// - Returns: Return a cancellable Network Request
    @discardableResult
    func request<E>(
        with endpoint: E,
        queue: DispatchQueue = .main,
        progressHUD: SNProgressHUD? = nil,
        completion: @escaping (Response<E.Response>) -> Void
    ) -> NetworkCancellable? where E: Requestable, E.Response == Void {
        guard
            let request = try? endpoint.urlRequest(with: config)
        else {
            completion(
                Response(
                    result: .failure(.urlGeneration),
                    session: session,
                    request: nil,
                    response: nil
                )
            )
            return nil
        }
        
        progressHUD?.show()
        let task = session?.dataTask(
            with: request
        ) { [weak self] (data, response, error) in
            guard let self = self else {
                progressHUD?.dismiss()
                return
            }
            
            queue.async {
                defer { progressHUD?.dismiss() }
                
                if self.config.debug, let session = self.session {
                    SmartNet.printCurl(
                        session: session,
                        request: request,
                        data: data
                    )
                }
                
                if let networkError = self.getRequestError(
                    data: data,
                    response: response,
                    requestError: error
                ) {
                    completion(
                        Response(
                            result: .failure(networkError),
                            session: self.session,
                            request: request,
                            response: response
                        )
                    )
                    return
                }
                completion(
                    Response(
                        result: .success(()),
                        session: self.session,
                        request: request,
                        response: response
                    )
                )
            }
        }
        task?.resume()
        return task
    }
    
}
