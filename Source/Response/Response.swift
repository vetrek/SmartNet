//
//  Response.swift
//
//
//  Created by Valerio Sebastianelli on 10/16/21.
//

import Foundation

/// A wrapper for network request results that includes metadata about the request and response.
///
/// `Response` encapsulates the result of a network request along with the original
/// `URLRequest`, `URLResponse`, and convenience accessors for the HTTP status code,
/// successful value, and error.
///
/// Example:
/// ```swift
/// apiClient.request(with: endpoint) { response in
///     print("Status: \(response.statusCode)")
///     if let value = response.value {
///         // Handle success
///     } else if let error = response.error {
///         // Handle error
///     }
/// }
/// ```
public struct Response<Value: Sendable>: Sendable {
  /// The result of the network request, either success with a value or failure with an error.
  /// The result of the network request, either success with a value or failure with an error.
  public let result: Result<Value>

  /// The URL request that was sent.
  public private(set) var request: URLRequest?

  /// The URL response received from the server.
  public private(set) var response: URLResponse?
  
  var session: URLSession?

  /// Creates a response with just a result.
  ///
  /// - Parameter result: The result of the network request.
  public init(result: Result<Value>) {
    self.result = result
    self.session = nil
    self.request = nil
  }
  
  init(result: Result<Value>, session: URLSession?, request: URLRequest? = nil, response: URLResponse? = nil) {
    self.result = result
    self.session = session
    self.request = request
    self.response = response
  }
  
  /// Prints the cURL representation of the request to the console.
  ///
  /// Useful for debugging network requests. The output can be copied and
  /// executed in a terminal to reproduce the request.
  // Original source: https://github.com/Alamofire/Alamofire/blob/c039ac798b5acb91830dc64e8fe5de96970a4478/Source/Request.swift#L962
  public func printCurl() {
    guard
      let session = session,
      let request = self.request
    else { return }
    ApiClient.printCurl(session: session, request: request, response: response)
  }

  /// The HTTP status code of the response, or -1 if not available.
  public var statusCode: Int {
    (response as? HTTPURLResponse)?.statusCode ?? -1
  }

  /// The successful value if the result is `.success`, otherwise `nil`.
  public var value: Value? {
    result.value
  }

  /// The error if the result is `.failure`, otherwise `nil`.
  public var error: Error? {
    result.error
  }
}

extension Response {
  func convertedTo<T>(result: Result<T>) -> Response<T> {
    Response<T>(
      result: result,
      session: session,
      request: request,
      response: response
    )
  }
}
