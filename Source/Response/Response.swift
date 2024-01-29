//
//  File.swift
//  
//
//  Created by Valerio Sebastianelli on 10/16/21.
//

import Foundation

public struct Response<Value> {
  public let result: Result<Value>
  public private(set) var request: URLRequest?
  public private(set) var response: URLResponse?
  
  var session: URLSession?
  
  public init(result: Result<Value>) {
    self.result = result
    self.session = nil
    self.request = nil
  }
  
  init(result: Result<Value>, session: URLSession?, request: URLRequest?, response: URLResponse?) {
    self.result = result
    self.session = session
    self.request = request
    self.response = response
  }
  
  // Original source: https://github.com/Alamofire/Alamofire/blob/c039ac798b5acb91830dc64e8fe5de96970a4478/Source/Request.swift#L962
  public func printCurl() {
    guard
      let session = session,
      let request = self.request
    else { return }
    ApiClient.printCurl(session: session, request: request, response: response)
  }
  
  public var statusCode: Int {
    (response as? HTTPURLResponse)?.statusCode ?? -1
  }
  
  public var value: Value? {
    result.value
  }
  
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
