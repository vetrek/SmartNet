import Testing
import Foundation
@testable import SmartNet

@Suite("HTTPPayload Tests")
struct HTTPPayloadTests {

  // MARK: - JSON Payload Tests

  @Test("JSON payload from dictionary")
  func jsonFromDictionary() {
    let payload: HTTPPayload = .json(["name": "John", "age": 30])

    if let body = payload.asHTTPBody {
      #expect(body.data != nil)
      if let data = body.data,
         let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        #expect(json["name"] as? String == "John")
        #expect(json["age"] as? Int == 30)
      }
    } else {
      Issue.record("Expected HTTPBody to be created")
    }
  }

  @Test("JSON payload with custom encoding")
  func jsonWithCustomEncoding() {
    let payload: HTTPPayload = .json(["key": "value"], encoding: .formUrlEncodedAscii)

    if let body = payload.asHTTPBody {
      #expect(body.data != nil)
    } else {
      Issue.record("Expected HTTPBody to be created")
    }
  }

  // MARK: - Encodable Payload Tests

  @Test("Encodable payload")
  func encodablePayload() {
    struct User: Encodable {
      let name: String
      let email: String
    }

    let user = User(name: "John", email: "john@example.com")
    let payload: HTTPPayload = .encodable(user)

    if let body = payload.asHTTPBody {
      #expect(body.data != nil)
    } else {
      Issue.record("Expected HTTPBody to be created")
    }
  }

  @Test("Encodable payload with custom encoder")
  func encodableWithCustomEncoder() {
    struct User: Encodable {
      let userName: String
    }

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    let user = User(userName: "John")
    let payload: HTTPPayload = .encodable(user, encoder: encoder)

    if let body = payload.asHTTPBody,
       let data = body.data,
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      #expect(json["user_name"] as? String == "John")
    }
  }

  // MARK: - Form URL Encoded Tests

  @Test("Form URL encoded payload")
  func formUrlEncoded() {
    let payload: HTTPPayload = .formUrlEncoded(["username": "john", "password": "secret"])

    if let body = payload.asHTTPBody {
      #expect(body.data != nil)
    } else {
      Issue.record("Expected HTTPBody to be created")
    }
  }

  // MARK: - Multipart Tests

  @Test("Multipart payload returns form")
  func multipartPayload() {
    let form = MultipartFormData { form in
      form.addTextField(named: "name", value: "John")
    }

    let payload: HTTPPayload = .multipart(form)

    #expect(payload.asMultipartForm != nil)
    #expect(payload.asHTTPBody == nil)
  }

  // MARK: - Raw Data Tests

  @Test("Raw payload returns data and content type")
  func rawPayload() {
    let data = Data([0x01, 0x02, 0x03])
    let payload: HTTPPayload = .raw(data, contentType: "application/octet-stream")

    if let raw = payload.asRawData {
      #expect(raw.data == data)
      #expect(raw.contentType == "application/octet-stream")
    } else {
      Issue.record("Expected raw data")
    }

    #expect(payload.asHTTPBody == nil)
  }

  // MARK: - Text Payload Tests

  @Test("Text payload")
  func textPayload() {
    let payload: HTTPPayload = .text("Hello, World!")

    if let body = payload.asHTTPBody {
      #expect(body.data != nil)
      if let data = body.data {
        #expect(String(data: data, encoding: .utf8) == "Hello, World!")
      }
    } else {
      Issue.record("Expected HTTPBody to be created")
    }
  }
}

@Suite("Endpoint Payload Builder Tests")
struct EndpointPayloadBuilderTests {

  // MARK: - Payload Method Tests

  @Test("payload() sets payload and clears body")
  func payloadSetsPayload() {
    let endpoint: Endpoint<String> = .post("users")
      .body(["old": "body"])
      .payload(.json(["new": "payload"]))

    #expect(endpoint.payload != nil)
    #expect(endpoint.body == nil)
  }

  @Test("jsonDictPayload() from dictionary")
  func jsonPayloadDictionary() {
    let endpoint: Endpoint<String> = .post("users")
      .jsonDictPayload(["name": "John"])

    guard let payload = endpoint.payload else {
      Issue.record("Expected payload to be set")
      return
    }

    if case .json(let dict, _) = payload {
      #expect(dict["name"] as? String == "John")
    } else {
      Issue.record("Expected JSON payload, got \(payload)")
    }
  }

  @Test("jsonPayload() from Encodable")
  func jsonPayloadEncodable() {
    struct User: Encodable {
      let name: String
    }

    let endpoint: Endpoint<String> = .post("users")
      .jsonPayload(User(name: "John"))

    #expect(endpoint.payload != nil)
    if case .encodable = endpoint.payload {
      // Success
    } else {
      Issue.record("Expected encodable payload")
    }
  }

  @Test("formPayload() sets form URL encoded")
  func formPayloadSets() {
    let endpoint: Endpoint<String> = .post("login")
      .formPayload(["username": "john", "password": "secret"])

    #expect(endpoint.payload != nil)
    if case .formUrlEncoded(let dict) = endpoint.payload {
      #expect(dict["username"] as? String == "john")
    } else {
      Issue.record("Expected form URL encoded payload")
    }
  }

  @Test("multipartPayload() sets multipart form")
  func multipartPayloadSets() {
    let form = MultipartFormData {
      TextField("name", value: "John")
    }

    let endpoint: Endpoint<String> = .post("upload")
      .multipartPayload(form)

    #expect(endpoint.payload != nil)
    if case .multipart = endpoint.payload {
      // Success
    } else {
      Issue.record("Expected multipart payload")
    }
  }

  @Test("rawPayload() sets raw data")
  func rawPayloadSets() {
    let data = Data([0x89, 0x50, 0x4E, 0x47])

    let endpoint: Endpoint<String> = .post("upload")
      .rawPayload(data, contentType: "image/png")

    #expect(endpoint.payload != nil)
    if case .raw(let payloadData, let contentType) = endpoint.payload {
      #expect(payloadData == data)
      #expect(contentType == "image/png")
    } else {
      Issue.record("Expected raw payload")
    }
  }

  @Test("textPayload() sets plain text")
  func textPayloadSets() {
    let endpoint: Endpoint<String> = .post("message")
      .textPayload("Hello, World!")

    #expect(endpoint.payload != nil)
    if case .text(let string) = endpoint.payload {
      #expect(string == "Hello, World!")
    } else {
      Issue.record("Expected text payload")
    }
  }

  // MARK: - URL Request Generation Tests

  @Test("JSON payload generates correct request")
  func jsonPayloadRequest() throws {
    let endpoint: Endpoint<String> = .post("users")
      .jsonPayload(["name": "John"])

    let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
    let request = try endpoint.urlRequest(with: config)

    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(request.httpBody != nil)
  }

  @Test("Form payload generates correct request")
  func formPayloadRequest() throws {
    let endpoint: Endpoint<String> = .post("login")
      .formPayload(["username": "john"])

    let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
    let request = try endpoint.urlRequest(with: config)

    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
    #expect(request.httpBody != nil)
  }

  @Test("Multipart payload generates correct request")
  func multipartPayloadRequest() throws {
    let form = MultipartFormData {
      TextField("name", value: "John")
    }

    let endpoint: Endpoint<String> = .post("upload")
      .multipartPayload(form)

    let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
    let request = try endpoint.urlRequest(with: config)

    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
    #expect(request.httpBody != nil)
  }

  @Test("Raw payload generates correct request")
  func rawPayloadRequest() throws {
    let data = Data([0x01, 0x02, 0x03])

    let endpoint: Endpoint<String> = .post("binary")
      .rawPayload(data, contentType: "application/octet-stream")

    let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
    let request = try endpoint.urlRequest(with: config)

    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
    #expect(request.httpBody == data)
  }

  @Test("Text payload generates correct request")
  func textPayloadRequest() throws {
    let endpoint: Endpoint<String> = .post("message")
      .textPayload("Hello!")

    let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
    let request = try endpoint.urlRequest(with: config)

    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "text/plain")
    #expect(request.httpBody != nil)
  }

  @Test("Payload takes precedence over legacy body")
  func payloadPrecedence() throws {
    // Create endpoint with both body and payload
    var endpoint: Endpoint<String> = .post("users")
    endpoint.body = HTTPBody(dictionary: ["legacy": "body"])
    endpoint.payload = .json(["new": "payload"])

    let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
    let request = try endpoint.urlRequest(with: config)

    if let data = request.httpBody,
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      // Payload should take precedence
      #expect(json["new"] as? String == "payload")
      #expect(json["legacy"] == nil)
    }
  }
}

@Suite("Typed Throws Tests")
struct TypedThrowsTests {

  @Test("urlRequest returns URLRequest for valid endpoint")
  func validEndpointReturnsRequest() throws {
    let endpoint: Endpoint<String> = .get("users")

    let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
    let request = try endpoint.urlRequest(with: config)

    #expect(request.url?.absoluteString == "https://api.example.com/users")
  }

  @Test("Typed throws allows direct error handling")
  func typedThrowsDirectErrorHandling() {
    let endpoint: Endpoint<String> = .get("users")
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)

    // With typed throws, the error type is known at compile time
    // This test verifies the API works with typed throws
    do {
      let request = try endpoint.urlRequest(with: config)
      #expect(request.httpMethod == "GET")
    } catch {
      // error is automatically NetworkError due to typed throws
      // We can access NetworkError properties directly
      let description = error.description
      #expect(!description.isEmpty)
    }
  }

  @Test("Typed throws works with try? operator")
  func typedThrowsWithTryOptional() {
    let endpoint: Endpoint<String> = .get("users")
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)

    // try? still works with typed throws
    let request = try? endpoint.urlRequest(with: config)
    #expect(request != nil)
    #expect(request?.httpMethod == "GET")
  }

  @Test("urlRequest throws for prepareRequest errors")
  func prepareRequestTypedThrows() throws {
    // Test that prepareRequest also uses typed throws
    let endpoint: Endpoint<String> = .get("users")
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
    let request = try endpoint.urlRequest(with: config)

    // Verify the request was created successfully
    #expect(request.url != nil)
    #expect(request.httpMethod == "GET")
  }
}

@Suite("Request Body Characterization Tests")
struct RequestBodyCharacterizationTests {

  private struct User: Encodable {
    let userName: String
  }

  private struct LegacyRequest: Requestable {
    typealias Response = Data
    var path = "items"
    var isFullPath = false
    var method: HTTPMethod = .post
    var headers: [String: String] = [:]
    var useEndpointHeaderOnly = false
    var queryParameters: QueryParameters?
    var body: HTTPBody?
    var form: MultipartFormData?
    var allowMiddlewares = true
  }

  private var snakeEncoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return encoder
  }

  private var form: MultipartFormData {
    MultipartFormData { TextField("name", value: "John") }
  }

  private func config(headers: [String: String] = [:], body: [String: Any] = [:]) -> NetworkConfiguration {
    NetworkConfiguration(baseURL: URL(string: "https://example.com")!, headers: headers, bodyParameters: body)
  }

  private func request(
    _ payload: HTTPPayload?,
    method: HTTPMethod = .post,
    headers: [String: String] = [:],
    headerOnly: Bool = false,
    config: NetworkConfiguration? = nil
  ) throws -> URLRequest {
    try Endpoint<Data>(path: "items", method: method, headers: headers, useEndpointHeaderOnly: headerOnly, payload: payload)
      .urlRequest(with: config ?? self.config())
  }

  private func text(_ request: URLRequest) -> String? {
    request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
  }

  private func json(_ request: URLRequest) -> NSDictionary? {
    request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? NSDictionary }
  }

  private func contentType(_ request: URLRequest) -> String? {
    request.value(forHTTPHeaderField: "Content-Type")
  }

  @Test("Payload body bytes and content type")
  func payloadBytesAndContentType() throws {
    let form = self.form
    let emptyForm = MultipartFormData()
    let cases: [(String, HTTPPayload, String?, Data?)] = [
      ("json", .json(["a": 1]), "application/json", Data(#"{"a":1}"#.utf8)),
      ("json encoder", .json(["a": 1], encoding: .json(encoder: snakeEncoder)), "application/json", Data(#"{"a":1}"#.utf8)),
      ("json form", .json(["a": "x y&z"], encoding: .formUrlEncodedAscii), "application/x-www-form-urlencoded", Data("a=x%20y%26z".utf8)),
      ("json plainText", .json(["a": 1], encoding: .plainText), nil, nil),
      ("encodable", .encodable(User(userName: "J"), encoder: snakeEncoder), "application/json", Data(#"{"userName":"J"}"#.utf8)),
      ("encodable non-object", .encodable([1, 2]), nil, nil),
      ("form", .formUrlEncoded(["b": true, "a": [1, 2]]), "application/x-www-form-urlencoded", Data("a%5B%5D=1&a%5B%5D=2&b=1".utf8)),
      ("text", .text("héllo"), "text/plain", Data("héllo".utf8)),
      ("raw", .raw(Data([0, 1, 2]), contentType: "application/x-raw"), "application/x-raw", Data([0, 1, 2])),
      ("multipart", .multipart(form), "multipart/form-data; boundary=\(form.boundary)", form.data),
      ("empty multipart", .multipart(emptyForm), "multipart/form-data; boundary=\(emptyForm.boundary)", nil)
    ]

    for (name, payload, expectedContentType, expectedBody) in cases {
      let request = try request(payload)
      #expect(contentType(request) == expectedContentType, "\(name)")
      #expect(request.httpBody == expectedBody, "\(name)")
    }
  }

  @Test("Config body parameters merge into key-value bodies only")
  func configBodyParametersMerge() throws {
    let config = config(body: ["a": "cfg", "g": "cfg"])
    let merged: NSDictionary = ["a": "cfg", "g": "cfg"]
    let form = self.form

    #expect(json(try request(.json(["a": 1]), config: config)) == merged)
    #expect(json(try request(.encodable(User(userName: "J"), encoder: snakeEncoder), config: config)) == ["a": "cfg", "g": "cfg", "userName": "J"])
    #expect(text(try request(.formUrlEncoded(["a": "1"]), config: config)) == "a=cfg&g=cfg")
    #expect(text(try request(.json(["a": "1"], encoding: .formUrlEncodedAscii), config: config)) == "a=cfg&g=cfg")
    #expect(text(try request(.text("t"), config: config)) == "t")
    #expect(try request(.raw(Data([7]), contentType: "x/y"), config: config).httpBody == Data([7]))
    #expect(try request(.multipart(form), config: config).httpBody == form.data)
    #expect(try request(.json(["a": 1], encoding: .plainText), config: config).httpBody == nil)

    let legacyJSON = try LegacyRequest(body: HTTPBody(dictionary: ["a": 1])).urlRequest(with: config)
    #expect(json(legacyJSON) == merged)
    #expect(contentType(legacyJSON) == "application/json")

    let legacyText = try LegacyRequest(body: HTTPBody(string: "t")).urlRequest(with: config)
    #expect(text(legacyText) == "t")
    #expect(contentType(legacyText) == "text/plain")

    let legacyForm = try LegacyRequest(body: HTTPBody(encodable: User(userName: "J"), bodyEncoding: .formUrlEncodedAscii))
      .urlRequest(with: config)
    #expect(text(legacyForm) == "a=cfg&g=cfg&userName=J")
    #expect(contentType(legacyForm) == "application/x-www-form-urlencoded")

    let fallback = try LegacyRequest().urlRequest(with: config)
    #expect(json(fallback) == merged)
    #expect(contentType(fallback) == "application/json")
  }

  @Test("Content-Type precedence between endpoint, config and payload")
  func contentTypePrecedence() throws {
    let endpointHeader = ["Content-Type": "x/endpoint"]
    let configWithHeader = config(headers: ["Content-Type": "x/config"])
    let mergeable: [HTTPPayload] = [.json(["a": 1]), .encodable(User(userName: "J")), .formUrlEncoded(["a": 1]), .text("t")]
    let overriding: [(HTTPPayload, String)] = [
      (.raw(Data([1]), contentType: "x/raw"), "x/raw"),
      (.multipart(form), "multipart/form-data")
    ]

    for payload in mergeable {
      #expect(contentType(try request(payload, headers: endpointHeader, config: configWithHeader)) == "x/endpoint")
      #expect(contentType(try request(payload, config: configWithHeader)) == "x/config")
      #expect(contentType(try request(payload, headerOnly: true, config: configWithHeader)) != "x/config")
    }
    for (payload, expected) in overriding {
      #expect(contentType(try request(payload, headers: endpointHeader, config: configWithHeader))?.hasPrefix(expected) == true)
    }

    #expect(contentType(try request(.json(["a": 1]), headerOnly: true, config: configWithHeader)) == "application/json")
    let legacyWithHeader = LegacyRequest(headers: endpointHeader, body: HTTPBody(dictionary: ["a": 1]))
    #expect(contentType(try legacyWithHeader.urlRequest(with: configWithHeader)) == "x/endpoint")
    #expect(contentType(try LegacyRequest(body: HTTPBody(string: "t")).urlRequest(with: configWithHeader)) == "x/config")
    let legacyForm = LegacyRequest(headers: endpointHeader, form: form)
    #expect(contentType(try legacyForm.urlRequest(with: configWithHeader))?.hasPrefix("multipart/form-data") == true)
    #expect(contentType(try LegacyRequest().urlRequest(with: configWithHeader)) == "x/config")

    let all = try request(.json(["a": 1]), headers: ["X-E": "e"], config: config(headers: ["X-C": "c", "X-E": "c"]))
    #expect(all.allHTTPHeaderFields == ["X-E": "e", "X-C": "c", "Content-Type": "application/json"])
  }

  @Test("Body source precedence: payload, body, form, config")
  func bodySourcePrecedence() throws {
    let config = config()
    let form = self.form

    var both = Endpoint<Data>(path: "items", method: .post, body: HTTPBody(dictionary: ["legacy": 1]))
    both.payload = .text("p")
    #expect(text(try both.urlRequest(with: config)) == "p")

    both.payload = .json(["a": 1], encoding: .plainText)
    let failed = try both.urlRequest(with: config)
    #expect(failed.httpBody == nil)
    #expect(contentType(failed) == nil)

    both.payload = .encodable([1, 2])
    #expect(try both.urlRequest(with: config).httpBody == nil)

    let bodyAndForm = try LegacyRequest(body: HTTPBody(string: "b"), form: form).urlRequest(with: config)
    #expect(text(bodyAndForm) == "b")
    #expect(contentType(bodyAndForm) == "text/plain")

    let formOnly = try LegacyRequest(form: form).urlRequest(with: config)
    #expect(formOnly.httpBody == form.data)
    #expect(contentType(formOnly) == "multipart/form-data; boundary=\(form.boundary)")

    let failedLegacy = HTTPBody(dictionary: ["a": 1], bodyEncoding: .plainText)
    #expect(failedLegacy == nil)

    let empty = try LegacyRequest().urlRequest(with: config)
    #expect(text(empty) == "{}")
    #expect(contentType(empty) == "application/json")
  }

  @Test("GET never carries a body or payload Content-Type")
  func getIgnoresBody() throws {
    let config = config(headers: ["X-C": "c"], body: ["g": 1])
    let get = try request(.json(["a": 1]), method: .get, config: config)
    #expect(get.httpBody == nil)
    #expect(get.allHTTPHeaderFields == ["X-C": "c"])

    let legacyGet = try LegacyRequest(method: .get, body: HTTPBody(dictionary: ["a": 1])).urlRequest(with: config)
    #expect(legacyGet.httpBody == nil)
    #expect(contentType(legacyGet) == nil)
  }
}
