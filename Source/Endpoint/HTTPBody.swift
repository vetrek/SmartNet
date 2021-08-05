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
    public let data: Data?

    public init(dictionary: [String: Any], bodyEncoding: BodyEncoding) throws {
        self.data = try HTTPBody.getData(from: dictionary, using: bodyEncoding)
    }

    public init(encodable: Encodable, bodyEncoding: BodyEncoding) throws {
        guard
            let dictionary = try encodable.toDictionary()
        else {
            fatalError("Unable to convert Encodable to Dictionary")
        }
        self.data = try HTTPBody.getData(from: dictionary, using: bodyEncoding)
    }

    public init(string: String) {
        guard
            let data = string.data(using: .utf8)
        else {
            fatalError("Unable to convert String \(string) to Data")
        }
        self.data = data
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
