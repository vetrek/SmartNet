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

import Combine
import Foundation

// MARK: - Networking Closure

public extension SmartNet {
  func request<D, E>(
    with endpoint: E,
    decoder: JSONDecoder = .default,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil
  ) -> AnyPublisher<D, Error> where D: Decodable, D == E.Response, E: Requestable {
    dataRequest(with: endpoint)
      .decode(type: D.self, decoder: decoder)
      .eraseToAnyPublisher()
  }
  
  func request<E>(
    with endpoint: E,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil
  ) -> AnyPublisher<E.Response, Error> where E: Requestable, E.Response == Data {
    dataRequest(with: endpoint)
  }
  
  func request<E>(
    with endpoint: E,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil
  ) -> AnyPublisher<E.Response, Error> where E: Requestable, E.Response == String {
    dataRequest(with: endpoint)
      .tryMap { data in
        guard
          let string = String(data: data, encoding: .utf8)
        else {
          throw NetworkError.dataToStringFailure(data: data)
        }
        return string
      }
      .eraseToAnyPublisher()
  }
  
  func request<E>(
    with endpoint: E,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil
  ) -> AnyPublisher<E.Response, Error> where E: Requestable, E.Response == Void {
    dataRequest(with: endpoint)
       .map { _ in return Void() } // Convert received Data to Void
       .eraseToAnyPublisher()
  }
  
  @discardableResult
  internal func dataRequest<E>(
    with endpoint: E,
    queue: DispatchQueue = .main,
    progressHUD: SNProgressHUD? = nil
  ) -> AnyPublisher<Data, Error> where E : Requestable {
    Future<Data, Error> { [weak self] promise in
      self?.dataRequest(with: endpoint, progressHUD: progressHUD) { response in
        switch response.result {
        case .success(let data):
          promise(.success(data))
        case .failure(let error):
          promise(.failure(error))
        }
      }
    }
    .receive(on: queue)
    .eraseToAnyPublisher()
  }
}
