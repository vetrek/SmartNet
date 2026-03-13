import Testing
import Foundation
@testable import SmartNet

@Suite("cURL Builder Tests")
struct CURLTests {

  private func makeSession() -> URLSession {
    URLSession(configuration: .ephemeral)
  }

  @Test("Includes URL at end of curl command")
  func includesURL() {
    var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
    request.httpMethod = "GET"

    let curl = ApiClient.buildCurl(session: makeSession(), request: request)

    #expect(curl != nil)
    #expect(curl!.contains("\"https://api.example.com/users\""))
    #expect(curl!.hasSuffix("\"https://api.example.com/users\""))
  }

  @Test("Includes HTTP method")
  func includesMethod() {
    var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
    request.httpMethod = "POST"

    let curl = ApiClient.buildCurl(session: makeSession(), request: request)

    #expect(curl!.contains("-X POST"))
  }

  @Test("Includes UTF-8 body as -d flag")
  func includesUTF8Body() {
    var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
    request.httpMethod = "POST"
    request.httpBody = "{\"name\":\"John\"}".data(using: .utf8)

    let curl = ApiClient.buildCurl(session: makeSession(), request: request)

    #expect(curl!.contains("-d"))
    #expect(curl!.contains("name"))
    #expect(curl!.contains("John"))
  }

  @Test("Binary body shows placeholder instead of corrupted data")
  func binaryBodyShowsPlaceholder() {
    var request = URLRequest(url: URL(string: "https://api.example.com/upload")!)
    request.httpMethod = "POST"
    // Gzip magic bytes followed by random binary data (invalid UTF-8)
    request.httpBody = Data([0x1f, 0x8b, 0x08, 0x00, 0xff, 0xfe, 0xfd, 0xfc, 0x80, 0x81])

    let curl = ApiClient.buildCurl(session: makeSession(), request: request)

    #expect(curl != nil)
    #expect(curl!.contains("-d <binary data, 10 bytes>"))
    // URL must still be present at the end
    #expect(curl!.contains("\"https://api.example.com/upload\""))
    #expect(curl!.hasSuffix("\"https://api.example.com/upload\""))
  }

  @Test("URL is present after binary body")
  func urlPresentAfterBinaryBody() {
    var request = URLRequest(url: URL(string: "https://api.example.com/data")!)
    request.httpMethod = "POST"
    request.httpBody = Data([0x80, 0x81, 0x82, 0x83])

    let curl = ApiClient.buildCurl(session: makeSession(), request: request)!
    let lines = curl.components(separatedBy: "\n")
    let lastLine = lines.last!.trimmingCharacters(in: .whitespaces)

    #expect(lastLine == "\"https://api.example.com/data\"")
  }

  @Test("Returns nil for request without URL")
  func returnsNilWithoutURL() {
    let request = URLRequest(url: URL(string: "https://example.com")!)
    // URLRequest always has a URL, but httpMethod can be nil for a fresh one
    var badRequest = request
    badRequest.url = nil

    let curl = ApiClient.buildCurl(session: makeSession(), request: badRequest)

    #expect(curl == nil)
  }

  @Test("Includes headers")
  func includesHeaders() {
    var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
    request.httpMethod = "GET"
    request.allHTTPHeaderFields = ["Authorization": "Bearer token123"]

    let curl = ApiClient.buildCurl(session: makeSession(), request: request)

    #expect(curl!.contains("-H \"Authorization: Bearer token123\""))
  }

  @Test("Escapes quotes in body")
  func escapesQuotesInBody() {
    var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
    request.httpMethod = "POST"
    request.httpBody = "{\"key\":\"value\"}".data(using: .utf8)

    let curl = ApiClient.buildCurl(session: makeSession(), request: request)

    #expect(curl!.contains("-d"))
    // The quotes inside the JSON should be escaped
    #expect(curl!.contains("\\\"key\\\""))
  }

  @Test("No body produces no -d flag")
  func noBodyNoDataFlag() {
    var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
    request.httpMethod = "GET"

    let curl = ApiClient.buildCurl(session: makeSession(), request: request)

    #expect(!curl!.contains("-d"))
  }
}
