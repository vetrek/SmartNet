//
//  MultipartFormEndpoint.swift
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

public struct MultipartFormEndpoint<Value>: Requestable {
  public typealias Response = Value
  
  public var path: String
  public var isFullPath: Bool
  public var method: HTTPMethod
  public var headers: [String: String]
  public var useEndpointHeaderOnly: Bool
  public var queryParameters: QueryParameters?
  public let body: HTTPBody? = nil
  public var allowMiddlewares: Bool
  public var form: MultipartFormData?
  public var debugRequest: Bool
  
  
  public init(
    path: String,
    isFullPath: Bool = false,
    method: HTTPMethod = .post,
    headers: [String: String] = [:],
    useEndpointHeaderOnly: Bool = false,
    queryParameters: QueryParameters? = nil,
    allowMiddlewares: Bool = true,
    form: MultipartFormData,
    debugRequest: Bool = false
  ) {
    self.path = path
    self.isFullPath = isFullPath
    self.method = method
    self.headers = headers
    self.useEndpointHeaderOnly = useEndpointHeaderOnly
    self.queryParameters = queryParameters
    self.allowMiddlewares = allowMiddlewares
    self.form = form
    self.debugRequest = debugRequest
  }
}

// https://orjpap.github.io/swift/http/ios/urlsession/2021/04/26/Multipart-Form-Requests.html
public struct MultipartFormData {
  private(set) var boundary: String = UUID().uuidString
  private var httpBody = NSMutableData()
  
  public init() { }
  
  public init(completion: (inout Self) -> Void) {
    var form = MultipartFormData()
    completion(&form)
    self = form
  }
  
  public func addTextField(
    named name: String,
    value: String
  ) {
    httpBody.append(textFormField(named: name, value: value))
  }
  
  private func textFormField(
    named name: String,
    value: String
  ) -> String {
    var fieldString = "--\(boundary)\r\n"
    fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
    fieldString += "Content-Type: text/plain; charset=UTF-8\r\n" // Updated to UTF-8
    fieldString += "Content-Transfer-Encoding: 8bit\r\n"
    fieldString += "\r\n"
    fieldString += "\(value)\r\n"
    
    return fieldString
  }
  
  public func addDataField(
    named name: String,
    data: Data,
    fileName: String? = nil,
    mimeType: String? = nil
  ) {
    httpBody.append(dataFormField(named: name, data: data, fileName: fileName, mimeType: mimeType))
  }
  
  private func dataFormField(
    named name: String,
    data: Data,
    fileName: String? = nil,
    mimeType: String? = nil
  ) -> Data {
    var disposition = "form-data; name=\"\(name)\""
    if let fileName = fileName {
      disposition += "; filename=\"\(fileName)\""
    }
    
    let fieldData = NSMutableData()
    fieldData.append("--\(boundary)\r\n")
    fieldData.append("Content-Disposition: \(disposition)\r\n")
    if let mimeType = mimeType {
      fieldData.append("Content-Type: \(mimeType)\r\n")
    }
    fieldData.append("\r\n")
    fieldData.append(data)
    fieldData.append("\r\n")
    
    return fieldData as Data
  }
  
  var data: Data? {
    guard
      httpBody.count > 0
    else { return nil }
    let body = NSMutableData(data: httpBody as Data)
    body.append("--\(boundary)--")
    return  body as Data
  }
  
}

extension NSMutableData {
  func append(_ string: String) {
    guard let data = string.data(using: .utf8) else { return }
    self.append(data)
  }
}

// MARK: - MultipartBuilder Result Builder

/// A result builder for declaratively constructing multipart form data.
///
/// Example usage:
/// ```swift
/// let form = MultipartFormData {
///   TextField("username", value: "johndoe")
///   TextField("email", value: "john@example.com")
///   DataField("avatar", data: imageData, fileName: "photo.png", mimeType: "image/png")
///   if includeMetadata {
///     TextField("metadata", value: jsonString)
///   }
/// }
/// ```
@resultBuilder
public struct MultipartBuilder {
  public static func buildBlock(_ components: MultipartFormField...) -> [MultipartFormField] {
    components
  }

  public static func buildBlock(_ components: [MultipartFormField]...) -> [MultipartFormField] {
    components.flatMap { $0 }
  }

  public static func buildOptional(_ component: [MultipartFormField]?) -> [MultipartFormField] {
    component ?? []
  }

  // Both required for if-else support; implementation is intentionally identical
  public static func buildEither(first component: [MultipartFormField]) -> [MultipartFormField] {
    component
  }

  public static func buildEither(second component: [MultipartFormField]) -> [MultipartFormField] {
    component
  }

  public static func buildArray(_ components: [[MultipartFormField]]) -> [MultipartFormField] {
    components.flatMap { $0 }
  }

  public static func buildExpression(_ expression: MultipartFormField) -> [MultipartFormField] {
    [expression]
  }

  public static func buildExpression(_ expression: [MultipartFormField]) -> [MultipartFormField] {
    expression
  }
}

// MARK: - MultipartFormField Protocol

/// A protocol representing a field in a multipart form.
public protocol MultipartFormField {
  /// Applies this field to the given multipart form data.
  func apply(to form: inout MultipartFormData)
}

// MARK: - TextField

/// A text field for multipart forms.
///
/// Example:
/// ```swift
/// TextField("username", value: "johndoe")
/// ```
public struct TextField: MultipartFormField {
  public let name: String
  public let value: String

  public init(_ name: String, value: String) {
    self.name = name
    self.value = value
  }

  public func apply(to form: inout MultipartFormData) {
    form.addTextField(named: name, value: value)
  }
}

// MARK: - DataField

/// A data/file field for multipart forms.
///
/// Example:
/// ```swift
/// DataField("file", data: fileData)
/// DataField("image", data: imageData, fileName: "photo.png", mimeType: "image/png")
/// ```
public struct DataField: MultipartFormField {
  public let name: String
  public let data: Data
  public let fileName: String?
  public let mimeType: String?

  public init(_ name: String, data: Data, fileName: String? = nil, mimeType: String? = nil) {
    self.name = name
    self.data = data
    self.fileName = fileName
    self.mimeType = mimeType
  }

  public func apply(to form: inout MultipartFormData) {
    form.addDataField(named: name, data: data, fileName: fileName, mimeType: mimeType)
  }
}

// MARK: - FileField

/// A convenience field for file uploads with automatic MIME type detection.
///
/// Example:
/// ```swift
/// FileField("document", data: pdfData, fileName: "report.pdf")
/// ```
public struct FileField: MultipartFormField {
  public let name: String
  public let data: Data
  public let fileName: String
  public let mimeType: String

  public init(_ name: String, data: Data, fileName: String, mimeType: String? = nil) {
    self.name = name
    self.data = data
    self.fileName = fileName
    self.mimeType = mimeType ?? Self.detectMimeType(for: fileName)
  }

  public func apply(to form: inout MultipartFormData) {
    form.addDataField(named: name, data: data, fileName: fileName, mimeType: mimeType)
  }

  /// Detects MIME type based on file extension.
  private static func detectMimeType(for fileName: String) -> String {
    let ext = (fileName as NSString).pathExtension.lowercased()
    switch ext {
    // Images
    case "jpg", "jpeg": return "image/jpeg"
    case "png": return "image/png"
    case "gif": return "image/gif"
    case "webp": return "image/webp"
    case "svg": return "image/svg+xml"
    case "heic": return "image/heic"
    // Documents
    case "pdf": return "application/pdf"
    case "json": return "application/json"
    case "xml": return "application/xml"
    case "txt": return "text/plain"
    case "html", "htm": return "text/html"
    case "css": return "text/css"
    case "js": return "application/javascript"
    // Archives
    case "zip": return "application/zip"
    case "gz", "gzip": return "application/gzip"
    case "tar": return "application/x-tar"
    // Audio
    case "mp3": return "audio/mpeg"
    case "wav": return "audio/wav"
    case "m4a": return "audio/mp4"
    // Video
    case "mp4": return "video/mp4"
    case "mov": return "video/quicktime"
    case "avi": return "video/x-msvideo"
    // Default
    default: return "application/octet-stream"
    }
  }
}

// MARK: - MultipartFormData Builder Extension

public extension MultipartFormData {
  /// Creates a multipart form using a result builder.
  ///
  /// Example:
  /// ```swift
  /// let form = MultipartFormData {
  ///   TextField("name", value: "John Doe")
  ///   TextField("email", value: "john@example.com")
  ///   FileField("avatar", data: imageData, fileName: "avatar.png")
  /// }
  /// ```
  init(@MultipartBuilder _ content: () -> [MultipartFormField]) {
    self.init()
    var mutableSelf = self
    for field in content() {
      field.apply(to: &mutableSelf)
    }
    self = mutableSelf
  }
}
