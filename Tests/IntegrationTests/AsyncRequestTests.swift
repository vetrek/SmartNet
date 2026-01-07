import Testing
import Foundation
@testable import SmartNet

@Suite("Async/Await Request Tests")
struct AsyncRequestTests {

  @Test("Decodable success")
  func decodableSuccess() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/async/decodable") }

    let expectedUser = TestUser(id: 1, name: "Jane Doe", email: "jane@example.com")

    MockURLProtocol.setHandler(for: "/async/decodable") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      let data = try! JSONEncoder().encode(expectedUser)
      return (response, data)
    }

    let endpoint = Endpoint<TestUser>(path: "async/decodable", method: .get)
    let user: TestUser = try await client.request(with: endpoint)

    #expect(user.id == expectedUser.id)
    #expect(user.name == expectedUser.name)
    #expect(user.email == expectedUser.email)
  }

  @Test("Data success")
  func dataSuccess() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/async/data") }

    let expectedData = "Raw data response".data(using: .utf8)!

    MockURLProtocol.setHandler(for: "/async/data") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, expectedData)
    }

    let endpoint = Endpoint<Data>(path: "async/data", method: .get)
    let data: Data = try await client.request(with: endpoint)

    #expect(data == expectedData)
  }

  @Test("String success")
  func stringSuccess() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/async/string") }

    let expectedString = "String response"

    MockURLProtocol.setHandler(for: "/async/string") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, expectedString.data(using: .utf8)!)
    }

    let endpoint = Endpoint<String>(path: "async/string", method: .get)
    let string: String = try await client.request(with: endpoint)

    #expect(string == expectedString)
  }

  @Test("HTTP 401 error throws")
  func http401Error() async {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/async/unauthorized") }

    MockURLProtocol.setHandler(for: "/async/unauthorized") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 401,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, "Unauthorized".data(using: .utf8)!)
    }

    let endpoint = Endpoint<TestUser>(path: "async/unauthorized", method: .get)

    do {
      let _: TestUser = try await client.request(with: endpoint)
      Issue.record("Expected error but got success")
    } catch let error as NetworkError {
      if case .error(let statusCode, _) = error {
        #expect(statusCode == 401)
      } else {
        Issue.record("Expected .error but got \(error)")
      }
    } catch {
      Issue.record("Unexpected error type: \(error)")
    }
  }

  @Test("Parsing failure throws")
  func parsingFailure() async {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/async/badjson") }

    MockURLProtocol.setHandler(for: "/async/badjson") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, "not json".data(using: .utf8)!)
    }

    let endpoint = Endpoint<TestUser>(path: "async/badjson", method: .get)

    do {
      let _: TestUser = try await client.request(with: endpoint)
      Issue.record("Expected parsing error but got success")
    } catch let error as NetworkError {
      if case .parsingFailed = error {
        // Expected
      } else {
        Issue.record("Expected .parsingFailed but got \(error)")
      }
    } catch {
      Issue.record("Unexpected error type: \(error)")
    }
  }
}
