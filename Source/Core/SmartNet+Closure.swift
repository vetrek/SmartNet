//
//  File.swift
//  
//
//  Created by Valerio Sebastianelli on 12/4/21.
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
        
        let task = session?.dataTask(
            with: request
        ) { [weak self] (data, response, error) in
            guard let self = self else { return }
            queue.async {
                if self.config.printCurl,
                   let session = self.session {
                    SmartNet.printCurl(
                        session: session,
                        request: request
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
        
        let task = session?.dataTask(
            with: request
        ) { [weak self] (data, response, error) in
            guard let self = self else { return }
            queue.async {
                if self.config.printCurl,
                   let session = self.session {
                    SmartNet.printCurl(
                        session: session,
                        request: request
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
        
        let task = session?.dataTask(
            with: request
        ) { [weak self] (data, response, error) in
            guard let self = self else { return }
            queue.async {
                if self.config.printCurl,
                   let session = self.session {
                    SmartNet.printCurl(
                        session: session,
                        request: request
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
        
        let task = session?.dataTask(
            with: request
        ) { [weak self] (data, response, error) in
            guard let self = self else { return }
            queue.async {
                if self.config.printCurl,
                   let session = self.session {
                    SmartNet.printCurl(
                        session: session,
                        request: request
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
