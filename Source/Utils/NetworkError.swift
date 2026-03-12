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

public enum NetworkError: Error, CustomStringConvertible, Equatable {
  case error(statusCode: Int, data: Data?)
  case parsedError(error: Decodable)
  /// JSON parsing failed with optional context about the failure location
  /// - Parameters:
  ///   - keyPath: The JSON key path where parsing failed (e.g., "data.recoveryBaseline.recoveryBaseline")
  ///   - expectedType: The Swift type expected by the model (e.g., "Float", "Int")
  ///   - actualType: The JSON type received (e.g., "Double", "String")
  ///   - value: The problematic value as a string (if available)
  ///   - message: A description of what went wrong
  case parsingFailed(
    keyPath: String? = nil,
    expectedType: String? = nil,
    actualType: String? = nil,
    value: String? = nil,
    message: String? = nil
  )
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
    
    case .parsingFailed(let keyPath, let expectedType, let actualType, let value, let message):
      var description = "Failed to parse the JSON response."
      if let keyPath = keyPath {
        description += " Key path: '\(keyPath)'."
      }
      if let expectedType = expectedType, let actualType = actualType {
        description += " Expected type '\(expectedType)' but received '\(actualType)'."
      } else if let expectedType = expectedType {
        description += " Expected type '\(expectedType)'."
      } else if let actualType = actualType {
        description += " Received type '\(actualType)'."
      }
      if let value = value {
        description += " Value: '\(value)'."
      }
      if let message = message {
        description += " Reason: \(message)"
      }
      return description
    
    case .emptyResponse:
      return "The request returned an empty response."
    
    case .cancelled:
      return "The network request has been cancelled"
      
    case .middlewareMaxRetry:
      return "Middleware max retry request reached"
    
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
      return "Middleware error \(error.localizedDescription)"
      
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

// MARK: - DecodingError Helper

extension NetworkError {
  /// Creates a `parsingFailed` error with context extracted from a `DecodingError`
  /// - Parameter error: The original error from JSON decoding
  /// - Returns: A `NetworkError.parsingFailed` with detailed context about the failure location
  public static func parsingFailed(from error: Error) -> NetworkError {
    guard let decodingError = error as? DecodingError else {
      return .parsingFailed(message: error.localizedDescription)
    }
    
    let keyPath: String
    var expectedType: String? = nil
    var actualType: String? = nil
    var value: String? = nil
    var message: String? = nil
    
    switch decodingError {
    case .keyNotFound(let key, let context):
      keyPath = Self.formatKeyPath(context.codingPath + [key])
      message = "Key '\(key.stringValue)' not found"
      
    case .valueNotFound(let type, let context):
      keyPath = Self.formatKeyPath(context.codingPath)
      expectedType = Self.formatTypeName(type)
      actualType = "null"
      message = "Value is required but found null"
      
    case .typeMismatch(let type, let context):
      keyPath = Self.formatKeyPath(context.codingPath)
      expectedType = Self.formatTypeName(type)
      actualType = Self.extractActualType(from: context.debugDescription)
      message = context.debugDescription
      
    case .dataCorrupted(let context):
      keyPath = Self.formatKeyPath(context.codingPath)
      // Extract the underlying error message for more details
      if let underlyingError = context.underlyingError as NSError? {
        let debugDesc = underlyingError.userInfo[NSDebugDescriptionErrorKey] as? String ?? context.debugDescription
        
        // Parse messages like "Number 37.11 is not representable in Swift."
        // This happens when JSON has a decimal (Double) but model expects Int,
        // or when precision is lost converting to Float/Decimal
        if debugDesc.contains("Number") && debugDesc.contains("not representable") {
          let components = debugDesc.components(separatedBy: " ")
          if components.count > 1 {
            value = components[1]
            // Determine if it's a decimal number (has a dot)
            if let numValue = value, numValue.contains(".") {
              actualType = "Double (decimal number in JSON)"
              expectedType = "Int (integer expected by model)"
              message = "Cannot convert decimal value to integer. Change model property to Double or Float"
            } else {
              // Integer that's too large for the target type
              actualType = "Number (from JSON)"
              expectedType = "Int/Int32 (model property may be too small)"
              message = "Number is too large for the expected integer type"
            }
          }
        } else {
          message = debugDesc
        }
      } else {
        message = context.debugDescription
      }
      
    @unknown default:
      keyPath = ""
      message = decodingError.localizedDescription
    }
    
    return .parsingFailed(
      keyPath: keyPath.isEmpty ? nil : keyPath,
      expectedType: expectedType,
      actualType: actualType,
      value: value,
      message: message
    )
  }
  
  /// Formats an array of coding keys into a readable key path string
  private static func formatKeyPath(_ codingPath: [CodingKey]) -> String {
    codingPath.map { key in
      // Check if it's an array index
      if let intValue = key.intValue {
        return "[\(intValue)]"
      }
      return key.stringValue
    }.joined(separator: ".")
    .replacingOccurrences(of: ".[", with: "[") // Clean up array notation
  }
  
  /// Formats a Swift type into a readable string
  private static func formatTypeName(_ type: Any.Type) -> String {
    let fullName = String(describing: type)
    // Simplify common generic types
    if fullName.hasPrefix("Optional<") {
      let inner = fullName.dropFirst(9).dropLast(1)
      return "\(inner)?"
    }
    if fullName.hasPrefix("Array<") {
      let inner = fullName.dropFirst(6).dropLast(1)
      return "[\(inner)]"
    }
    if fullName.hasPrefix("Dictionary<") {
      return fullName
        .replacingOccurrences(of: "Dictionary<", with: "[")
        .replacingOccurrences(of: ", ", with: ": ")
        .dropLast().appending("]")
    }
    return fullName
  }
  
  /// Extracts the actual JSON type from a debug description
  private static func extractActualType(from debugDescription: String) -> String? {
    // Common patterns in debug descriptions:
    // "Expected to decode Double but found a string/data instead."
    // "Expected to decode Array<Any> but found a dictionary instead."
    let patterns = [
      "found a string": "String",
      "found an array": "Array",
      "found a dictionary": "Dictionary/Object",
      "found a number": "Number",
      "found a boolean": "Bool",
      "found null": "null",
      "found string": "String",
      "found array": "Array",
      "found dictionary": "Dictionary/Object",
      "found number": "Number",
      "found bool": "Bool"
    ]
    
    let lowercased = debugDescription.lowercased()
    for (pattern, type) in patterns {
      if lowercased.contains(pattern) {
        return type
      }
    }
    return nil
  }
}

// MARK: - Equatable

extension NetworkError {
  public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
    switch (lhs, rhs) {
    case (.error(let lhsCode, let lhsData), .error(let rhsCode, let rhsData)):
      return lhsCode == rhsCode && lhsData == rhsData

    case (.parsedError(let lhsError), .parsedError(let rhsError)):
      // Compare by string representation since Decodable isn't Equatable
      return String(describing: lhsError) == String(describing: rhsError)

    case (.parsingFailed(let lhsKeyPath, let lhsExpected, let lhsActual, let lhsValue, let lhsMessage),
          .parsingFailed(let rhsKeyPath, let rhsExpected, let rhsActual, let rhsValue, let rhsMessage)):
      return lhsKeyPath == rhsKeyPath && lhsExpected == rhsExpected && lhsActual == rhsActual 
        && lhsValue == rhsValue && lhsMessage == rhsMessage

    case
         (.emptyResponse, .emptyResponse),
         (.invalidSessions, .invalidSessions),
         (.invalidDownloadUrl, .invalidDownloadUrl),
         (.invalidDownloadFileData, .invalidDownloadFileData),
         (.cancelled, .cancelled),
         (.middlewareMaxRetry, .middlewareMaxRetry),
         (.networkFailure, .networkFailure),
         (.urlGeneration, .urlGeneration),
         (.invalidFormData, .invalidFormData),
         (.timeout, .timeout),
         (.dnsLookupFailed, .dnsLookupFailed),
         (.connectionLost, .connectionLost):
      return true

    case (.unableToSaveFile(let lhsURL), .unableToSaveFile(let rhsURL)):
      return lhsURL == rhsURL

    case (.dataToStringFailure(let lhsData), .dataToStringFailure(let rhsData)):
      return lhsData == rhsData

    case (.middleware(let lhsError), .middleware(let rhsError)):
      // Compare by localizedDescription since Error isn't Equatable
      return lhsError.localizedDescription == rhsError.localizedDescription

    case (.generic(let lhsError), .generic(let rhsError)):
      // Compare by localizedDescription since Error isn't Equatable
      return lhsError.localizedDescription == rhsError.localizedDescription

    case (.sslError(let lhsError), .sslError(let rhsError)):
      switch (lhsError, rhsError) {
      case (.none, .none):
        return true
      case (.some(let lhs), .some(let rhs)):
        return lhs.localizedDescription == rhs.localizedDescription
      default:
        return false
      }

    case (.rateLimited(let lhsRetry), .rateLimited(let rhsRetry)):
      return lhsRetry == rhsRetry

    default:
      return false
    }
  }
}
