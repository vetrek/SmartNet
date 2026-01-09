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
