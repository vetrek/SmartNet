//
//  SmartNet.swift
//  SmartNet
//
//  Created by Valerio Sebastianelli on 7/19/21.
//

import Foundation
import Combine

public protocol NetworkCancellable {
    func cancel()
}

extension URLSessionTask: NetworkCancellable { }

public typealias CompletionHandler<T> = (Result<T>) -> Void

public protocol NetworkingRequests {
    func request<D: Decodable, E: Requestable>(
        with endpoint: E,
        decoder: JSONDecoder,
        queue: DispatchQueue,
        completion: @escaping CompletionHandler<E.Response>
    ) -> NetworkCancellable? where E.Response == D

    func request<E: Requestable>(
        with endpoint: E,
        queue: DispatchQueue,
        completion: @escaping CompletionHandler<E.Response>
    ) -> NetworkCancellable? where E.Response == Data

    func request<E: Requestable>(
        with endpoint: E,
        queue: DispatchQueue,
        completion: @escaping CompletionHandler<E.Response>
    ) -> NetworkCancellable? where E.Response == String

    func request<E: Requestable>(
        with endpoint: E,
        queue: DispatchQueue,
        completion: @escaping CompletionHandler<E.Response>
    ) -> NetworkCancellable? where E.Response == Void

    // MARK: - Combine Publishers

    func request<D, E>(
        with endpoint: E,
        decoder: JSONDecoder
    ) -> AnyPublisher<D, NetworkError>? where D: Decodable, D == E.Response, E: Requestable

    func request<E>(
        with endpoint: E
    ) -> AnyPublisher<E.Response, NetworkError>? where E: Requestable, E.Response == Data

    func request<E>(
        with endpoint: E
    ) -> AnyPublisher<E.Response, NetworkError>? where E: Requestable, E.Response == String

    func request<E>(
        with endpoint: E
    ) -> AnyPublisher<E.Response, NetworkError>? where E: Requestable, E.Response == Void
}

public final class SmartNet: NSObject {

    /// Network Session Configuration
    public let config: NetworkConfigurable

    /// Session
    private var session: URLSession?

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
    func destroy() {
        session = nil
    }
}

extension SmartNet: NetworkingRequests {

    /// Create a request and convert the reponse `Data` to a `Decodable` object
    /// - Parameters:
    ///   - endpoint: The service `Endpoint`
    ///   - decoder: Json Decoder
    ///   - queue: completiuon DispatchQueue
    ///   - completion: response completion
    /// - Returns: Return a cancellable Network Request
    @discardableResult
    public func request<D, E>(
        with endpoint: E,
        decoder: JSONDecoder = .default,
        queue: DispatchQueue = .main,
        completion: @escaping (Result<E.Response>) -> Void
    ) -> NetworkCancellable? where D: Decodable, D == E.Response, E: Requestable {
        guard
            let request = try? endpoint.urlRequest(with: config)
        else {
            completion(.failure(.urlGeneration))
            return nil
        }

        let task = session?.dataTask(
            with: request
        ) { (data, response, error) in
            queue.async {
                if let networkError = self.getRequestError(
                    data: data,
                    response: response,
                    requestError: error
                ) {
                    completion(.failure(networkError))
                    return
                }

                guard
                    let data = data
                else {
                    completion(.failure(.emptyResponse))
                    return
                }

                guard
                    let responseObject = try? decoder.decode(D.self, from: data)
                else {
                    completion(.failure(.parsingFailed))
                    return
                }
                completion(.success(responseObject))
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
    public func request<E>(
        with endpoint: E,
        queue: DispatchQueue = .main,
        completion: @escaping (Result<E.Response>) -> Void
    ) -> NetworkCancellable? where E: Requestable, E.Response == Data {
        guard
            let request = try? endpoint.urlRequest(with: config)
        else {
            completion(.failure(.urlGeneration))
            return nil
        }

        let task = session?.dataTask(
            with: request
        ) { (data, response, error) in
            queue.async {
                if let networkError = self.getRequestError(
                    data: data,
                    response: response,
                    requestError: error
                ) {
                    completion(.failure(networkError))
                    return
                }

                guard
                    let data = data
                else {
                    completion(.failure(.emptyResponse))
                    return
                }

                completion(.success(data))
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
    public func request<E>(
        with endpoint: E,
        queue: DispatchQueue = .main,
        completion: @escaping (Result<E.Response>) -> Void
    ) -> NetworkCancellable? where E: Requestable, E.Response == String {
        guard
            let request = try? endpoint.urlRequest(with: config)
        else {
            completion(.failure(.urlGeneration))
            return nil
        }

        let task = session?.dataTask(
            with: request
        ) { (data, response, error) in
            queue.async {
                if let networkError = self.getRequestError(
                    data: data,
                    response: response,
                    requestError: error
                ) {
                    completion(.failure(networkError))
                    return
                }

                guard
                    let data = data
                else {
                    completion(.failure(.emptyResponse))
                    return
                }

                guard
                    let string = String(data: data, encoding: .utf8)
                else {
                    completion(.failure(.dataToStringFailure(data: data)))
                    return
                }

                completion(.success(string))
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
    public func request<E>(
        with endpoint: E,
        queue: DispatchQueue = .main,
        completion: @escaping (Result<E.Response>) -> Void
    ) -> NetworkCancellable? where E: Requestable, E.Response == Void {
        guard
            let request = try? endpoint.urlRequest(with: config)
        else {
            completion(.failure(.urlGeneration))
            return nil
        }

        let task = session?.dataTask(
            with: request
        ) { (data, response, error) in
            queue.async {
                if let networkError = self.getRequestError(
                    data: data,
                    response: response,
                    requestError: error
                ) {
                    completion(.failure(networkError))
                    return
                }

                completion(.success(()))
            }
        }
        task?.resume()
        return task
    }

}

// MARK: - Combine

extension SmartNet {

    /// Create a request and convert the reponse `Data` to a `Decodable` object
    /// - Parameters:
    ///   - endpoint: The service `Endpoint`
    ///   - decoder: Json Decoder
    /// - Returns: Return a `Publisher` containing the **Object** response
    public func request<D, E>(
        with endpoint: E,
        decoder: JSONDecoder = .default
    ) -> AnyPublisher<D, NetworkError>? where D: Decodable, D == E.Response, E: Requestable {
        guard
            let request = try? endpoint.urlRequest(with: config)
        else {
            return AnyPublisher(
                Fail<D, NetworkError>(error: NetworkError.urlGeneration)
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
    public func request<E>(
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
    public func request<E>(
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
    public func request<E>(
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

// MARK: - Errors Handling

private extension SmartNet {

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
        if let response = response as? HTTPURLResponse {
            return .error(statusCode: response.statusCode, data: data)
        } else {
            return self.resolve(error: requestError)
        }
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
