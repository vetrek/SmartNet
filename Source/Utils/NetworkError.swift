//
//  NetworkError.swift
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

public enum NetworkError: Error, CustomStringConvertible {
  case error(statusCode: Int, data: Data?)
  case parsedError(error: Decodable)
  case parsingFailed
  case emptyResponse
  case invalidSessions
  case invalidDownloadUrl
  case invalidDownloadFileData
  case unableToSaveFile(_ currentURL: URL?)
  case cancelled
  case middlewareMaxRetry
  case networkFailure
  case urlGeneration
  case invalidFormData
  case dataToStringFailure(data: Data)
  case middleware(Error)
  case generic(Error)

  // MARK: - Specific Network Error Cases

  /// Request timed out
  case timeout

  /// DNS lookup failed - unable to resolve hostname
  case dnsLookupFailed

  /// SSL/TLS error - certificate validation failed or secure connection issue
  case sslError(Error?)

  /// Connection was lost during the request
  case connectionLost

  /// Server returned 429 Too Many Requests with optional Retry-After header
  case rateLimited(retryAfter: TimeInterval?)
  
  public var description: String {
    switch self {
    case .error(let statusCode, let data):
      var body = ""
      if let data = data {
        body = String(data: data, encoding: .utf8) ?? ""
      }
      return """
            Error with status code: \(statusCode)\n
            Response Body:\n
            \(body)
            """
    
    case .parsingFailed:
      return "Failed to parse the JSON response."
    
    case .emptyResponse:
      return "The request returned an empty response."
    
    case .cancelled:
      return "The network request has been cancelled"
      
    case .middlewareMaxRetry:
      return "Middleware max rety request reached"
    
    case .networkFailure:
      return "Unable to perform the request."
    
    case .urlGeneration:
      return "Unable to convert Requestable to URLRequest"
      
    case .invalidFormData:
      return "MultipartForm Data is invalid"
    
    case .dataToStringFailure:
      return "Unable to convert response data to string"
    
    case .generic(let error):
      return "Generic error \(error.localizedDescription)"
    
    case .parsedError(let error):
      return "Generic error \(error)"
    
    case .invalidSessions:
      return "Invalid Session"
    
    case .invalidDownloadUrl:
      return "Invalid download URL"
      
    case .invalidDownloadFileData:
      return "Invalid download File Data"
      
    case .middleware(let error):
      return "Middlware error \(error.localizedDescription)"
      
    case .unableToSaveFile:
      return "Unable to save file to the custom Destination folder"

    case .timeout:
      return "The request timed out"

    case .dnsLookupFailed:
      return "DNS lookup failed - unable to resolve hostname"

    case .sslError(let underlyingError):
      if let error = underlyingError {
        return "SSL/TLS error: \(error.localizedDescription)"
      }
      return "SSL/TLS error - secure connection failed"

    case .connectionLost:
      return "The network connection was lost"

    case .rateLimited(let retryAfter):
      if let seconds = retryAfter {
        return "Rate limited - retry after \(Int(seconds)) seconds"
      }
      return "Rate limited (429 Too Many Requests)"
    }
  }
}

extension NetworkError: LocalizedError {
  public var errorDescription: String? { description }
}
