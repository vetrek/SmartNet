import XCTest
@testable import SmartNet

final class HTTPBodyTests: XCTestCase {

  func testInitWithDictionaryProducesJSONData() throws {
    let body = try XCTUnwrap(HTTPBody(dictionary: ["name": "Taylor"]))
    let data = try XCTUnwrap(body.data)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    XCTAssertEqual(json?["name"] as? String, "Taylor")
    if case .json = body.bodyEncoding {
      // expected
    } else {
      XCTFail("Expected JSON encoding")
    }
  }

  func testInitWithEncodableUsesProvidedEncoder() throws {
    struct Payload: Encodable { let id: Int }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    let body = try XCTUnwrap(HTTPBody(encodable: Payload(id: 7), bodyEncoding: .json(encoder: encoder)))
    let data = try XCTUnwrap(body.data)
    let jsonString = String(data: data, encoding: .utf8)

    XCTAssertEqual(jsonString, "{\"id\":7}")
  }

  func testFormURLEncodedEncoding() throws {
    let parameters: [String: Any] = ["name": "Taylor", "age": 30]
    let body = try XCTUnwrap(HTTPBody(dictionary: parameters, bodyEncoding: .formUrlEncodedAscii))
    let data = try XCTUnwrap(body.data)
    let string = try XCTUnwrap(String(data: data, encoding: .ascii))

    XCTAssertTrue(string.contains("name=Taylor"))
    XCTAssertTrue(string.contains("age=30"))
    if case .formUrlEncodedAscii = body.bodyEncoding {
      // expected
    } else {
      XCTFail("Expected form URL encoded ASCII encoding")
    }
  }

  func testStringBody() throws {
    let original = "hello world"
    let body = try XCTUnwrap(HTTPBody(string: original))

    XCTAssertEqual(String(data: try XCTUnwrap(body.data), encoding: .utf8), original)
    if case .plainText = body.bodyEncoding {
      // expected
    } else {
      XCTFail("Expected plain text encoding")
    }
  }
}
