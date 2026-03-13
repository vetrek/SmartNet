//
//  ApiClient+CURL.swift
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

// MARK: - cURL

extension ApiClient {
  // Original source: https://github.com/Alamofire/Alamofire/blob/c039ac798b5acb91830dc64e8fe5de96970a4478/Source/Request.swift#L962
  static func printCurl(
    session: URLSession,
    request: URLRequest,
    response: URLResponse? = nil,
    data: Data? = nil
  ) {
    let tag = "cUrl"
    guard let curl = buildCurl(session: session, request: request) else {
      SmartNetLogger.shared.warning("\(tag) - curl command could not be created")
      return
    }

    SmartNetLogger.shared.debug("\(tag) \(curl)")

    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
    let responseTag = "Response [\(statusCode)]"

    if let data = data, let jsonString = String(data: data, encoding: .utf8) {
      if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
        let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
        let prettyString = String(data: prettyData ?? data, encoding: .utf8) ?? jsonString
        SmartNetLogger.shared.debug("\(responseTag) \(prettyString)")
      } else {
        SmartNetLogger.shared.debug("\(responseTag) \(jsonString)")
      }
    }
  }

  static func buildCurl(
    session: URLSession,
    request: URLRequest
  ) -> String? {
    guard
      let url = request.url,
      let method = request.httpMethod
    else {
      return nil
    }

    var components = ["$ curl -v"]
    components.append("-X \(method)")

    if session.configuration.httpShouldSetCookies {
      if let cookieStorage = session.configuration.httpCookieStorage,
         let cookies = cookieStorage.cookies(for: url), !cookies.isEmpty {
        let allCookies = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: ";")

        components.append("-b \"\(allCookies)\"")
      }
    }

    var headers: [AnyHashable: Any] = [:]

    session.configuration.httpAdditionalHeaders?
      .filter {  $0.0 != AnyHashable("Cookie") }
      .forEach { headers[$0.0] = $0.1 }

    request.allHTTPHeaderFields?
      .filter { $0.0 != "Cookie" }
      .forEach { headers[$0.0] = $0.1 }

    components += headers.map {
      let escapedValue = String(describing: $0.value).replacingOccurrences(of: "\"", with: "\\\"")

      return "-H \"\($0.key): \(escapedValue)\""
    }

    if let httpBodyData = request.httpBody {
      if let httpBody = String(data: httpBodyData, encoding: .utf8) {
        var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"")
        escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"")
        components.append("-d \"\(escapedBody)\"")
      } else {
        components.append("-d <binary data, \(httpBodyData.count) bytes>")
      }
    }

    components.append("\"\(url.absoluteString)\"")

    return components.joined(separator: " \\\n\t")
  }
}
