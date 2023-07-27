//
//  HTTPBody.swift
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

public protocol SmartNetBody {
  var data: Data? { get }
}

public struct HTTPBody: SmartNetBody {
  enum BodyType {
    case keyValue
    case string
  }
  
  public let data: Data?
  
  var dictionary: [String: Any]?
  
  let bodyType: BodyType
  
  let bodyEncoding: BodyEncoding
  
  public init?(dictionary: [String: Any], bodyEncoding: BodyEncoding = .json) {
    guard
      let data = try? HTTPBody.getData(from: dictionary, using: bodyEncoding)
    else { return nil }
    self.bodyEncoding = bodyEncoding
    self.data = data
    self.dictionary = dictionary
    self.bodyType = .keyValue
  }
  
  public init?(encodable: Encodable, bodyEncoding: BodyEncoding = .json) {
    guard
      let dictionary = try? encodable.toDictionary(),
      let data = try? HTTPBody.getData(from: dictionary, using: bodyEncoding)
    else { return nil }
    self.bodyEncoding = bodyEncoding
    self.data = data
    self.dictionary = dictionary
    self.bodyType = .keyValue
  }
  
  public init?(string: String) {
    guard
      let data = string.data(using: .utf8)
    else { return nil }
    self.bodyEncoding = .plainText
    self.data = data
    self.bodyType = .string
  }
  
  mutating func addingKeyValues(keyValues: [String: Any]) -> Self {
    guard
      let dictionary,
      let newBody = HTTPBody(dictionary: dictionary.merging(keyValues, uniquingKeysWith: { $1 }))
    else { return self }
    self = newBody
    return self
  }
  
}

private extension HTTPBody {
  static func getData(
    from dictionary: [String: Any],
    using encoding: BodyEncoding
  ) throws -> Data? {
    switch encoding {
    case .json:
      return try JSONSerialization.data(withJSONObject: dictionary)
    case .formUrlEncodedAscii:
      return queryString(dictionary).data(using: String.Encoding.ascii, allowLossyConversion: true)
    default:
      return nil
    }
  }
  
  static func queryString(_ parameters: [String: Any]) -> String {
    var components: [(String, String)] = []
    
    for key in parameters.keys.sorted(by: <) {
      let value = parameters[key]!
      components += queryComponents(fromKey: key, value: value)
    }
    return components.map { "\($0)=\($1)" }.joined(separator: "&")
  }
  
  /// Creates percent-escaped, URL encoded query string components from the given key-value pair using recursion.
  ///
  /// - parameter key:   The key of the query component.
  /// - parameter value: The value of the query component.
  ///
  /// - returns: The percent-escaped, URL encoded query string components.
  static func queryComponents(fromKey key: String, value: Any) -> [(String, String)] {
    var components: [(String, String)] = []
    
    if let dictionary = value as? [String: Any] {
      for (nestedKey, value) in dictionary {
        components += queryComponents(fromKey: "\(key)[\(nestedKey)]", value: value)
      }
    } else if let array = value as? [Any] {
      for value in array {
        components += queryComponents(fromKey: "\(key)[]", value: value)
      }
    } else if let value = value as? NSNumber {
      if value.isBool {
        components.append((key.escaped, (value.boolValue ? "1" : "0").escaped))
      } else {
        components.append((key.escaped, "\(value)".escaped))
      }
    } else if let bool = value as? Bool {
      components.append((key.escaped, (bool ? "1" : "0").escaped))
    } else {
      components.append((key.escaped, "\(value)".escaped))
    }
    return components
  }
}

private extension NSNumber {
  var isBool: Bool {
    return CFBooleanGetTypeID() == CFGetTypeID(self)
  }
}
