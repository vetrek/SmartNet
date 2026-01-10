//
//  QueryParameters.swift
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

/// A type-safe wrapper for URL query parameters.
///
/// Use `QueryParameters` to attach query parameters to your endpoint requests.
/// You can initialize it with a dictionary or from any `Encodable` type.
///
/// Example:
/// ```swift
/// // From dictionary
/// let params = QueryParameters(parameters: ["page": 1, "limit": 20])
///
/// // From Encodable
/// struct SearchQuery: Encodable {
///     let query: String
///     let page: Int
/// }
/// let params = try QueryParameters(encodable: SearchQuery(query: "swift", page: 1))
/// ```
public struct QueryParameters {
  /// The underlying dictionary of query parameters.
  public let parameters: [String: Any]

  /// Creates query parameters from a dictionary.
  ///
  /// - Parameter parameters: A dictionary of parameter names to values.
  public init(parameters: [String: Any]) {
    self.parameters = parameters
  }

  /// Creates query parameters from an `Encodable` value.
  ///
  /// The encodable value is converted to a dictionary representation.
  ///
  /// - Parameter encodable: An `Encodable` value to convert to query parameters.
  /// - Throws: ``NetworkError/parsingFailed`` if the conversion fails.
  public init(encodable: Encodable) throws {
    guard let parameters = try encodable.toDictionary() else {
      throw NetworkError.parsingFailed
    }
    self.parameters = parameters
  }
}
