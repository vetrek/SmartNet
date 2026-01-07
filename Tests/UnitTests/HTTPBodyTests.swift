import Testing
import Foundation
@testable import SmartNet

@Suite("HTTPBody Tests")
struct HTTPBodyTests {

  @Test("Init with dictionary produces JSON data")
  func initWithDictionaryProducesJSONData() throws {
    let body = try #require(HTTPBody(dictionary: ["name": "Taylor"]))
    let data = try #require(body.data)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["name"] as? String == "Taylor")
    if case .json = body.bodyEncoding {
      // expected
    } else {
      Issue.record("Expected JSON encoding")
    }
  }

  @Test("Init with encodable uses provided encoder")
  func initWithEncodableUsesProvidedEncoder() throws {
    struct Payload: Encodable { let id: Int }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    let body = try #require(HTTPBody(encodable: Payload(id: 7), bodyEncoding: .json(encoder: encoder)))
    let data = try #require(body.data)
    let jsonString = String(data: data, encoding: .utf8)

    #expect(jsonString == "{\"id\":7}")
  }

  @Test("Form URL encoded encoding")
  func formURLEncodedEncoding() throws {
    let parameters: [String: Any] = ["name": "Taylor", "age": 30]
    let body = try #require(HTTPBody(dictionary: parameters, bodyEncoding: .formUrlEncodedAscii))
    let data = try #require(body.data)
    let string = try #require(String(data: data, encoding: .ascii))

    #expect(string.contains("name=Taylor"))
    #expect(string.contains("age=30"))
    if case .formUrlEncodedAscii = body.bodyEncoding {
      // expected
    } else {
      Issue.record("Expected form URL encoded ASCII encoding")
    }
  }

  @Test("String body")
  func stringBody() throws {
    let original = "hello world"
    let body = try #require(HTTPBody(string: original))

    #expect(String(data: try #require(body.data), encoding: .utf8) == original)
    if case .plainText = body.bodyEncoding {
      // expected
    } else {
      Issue.record("Expected plain text encoding")
    }
  }

  @Test("JSON encoding with custom encoder")
  func jsonEncodingWithCustomEncoder() throws {
    struct DatePayload: Encodable {
      let date: Date
    }

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]

    let testDate = Date(timeIntervalSince1970: 0) // 1970-01-01
    let payload = DatePayload(date: testDate)

    let body = try #require(HTTPBody(encodable: payload, bodyEncoding: .json(encoder: encoder)))
    let data = try #require(body.data)
    let jsonString = try #require(String(data: data, encoding: .utf8))

    #expect(jsonString.contains("1970-01-01"))
  }

  @Test("Empty dictionary produces empty JSON object")
  func emptyDictionaryProducesEmptyJSONObject() throws {
    let body = try #require(HTTPBody(dictionary: [:]))
    let data = try #require(body.data)
    let jsonString = try #require(String(data: data, encoding: .utf8))

    #expect(jsonString == "{}")
  }

  @Test("Nested dictionary produces nested JSON")
  func nestedDictionaryProducesNestedJSON() throws {
    let parameters: [String: Any] = [
      "user": [
        "name": "John",
        "age": 30
      ]
    ]

    let body = try #require(HTTPBody(dictionary: parameters))
    let data = try #require(body.data)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    let user = json?["user"] as? [String: Any]
    #expect(user?["name"] as? String == "John")
    #expect(user?["age"] as? Int == 30)
  }

  @Test("Array in dictionary")
  func arrayInDictionary() throws {
    let parameters: [String: Any] = [
      "tags": ["swift", "ios", "networking"]
    ]

    let body = try #require(HTTPBody(dictionary: parameters))
    let data = try #require(body.data)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    let tags = json?["tags"] as? [String]
    #expect(tags == ["swift", "ios", "networking"])
  }
}
