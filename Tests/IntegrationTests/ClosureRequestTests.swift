import Testing
import Foundation
@testable import SmartNet

@Suite("Closure Request Tests")
struct ClosureRequestTests {

  @Test("Decodable success response")
  func decodableSuccess() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/closure/decodable") }

    let expectedUser = TestUser(id: 1, name: "John Doe", email: "john@example.com")

    MockURLProtocol.setHandler(for: "/closure/decodable") { request in
      #expect(request.url?.path == "/closure/decodable")
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      let data = try! JSONEncoder().encode(expectedUser)
      return (response, data)
    }

    let endpoint = Endpoint<TestUser>(path: "closure/decodable", method: .get)

    let response: Response<TestUser> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    switch response.result {
    case .success(let user):
      #expect(user.id == expectedUser.id)
      #expect(user.name == expectedUser.name)
      #expect(user.email == expectedUser.email)
    case .failure(let error):
      Issue.record("Expected success but got error: \(error)")
    }
  }

  @Test("Data success response")
  func dataSuccess() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/closure/data") }

    let expectedData = "Hello, World!".data(using: .utf8)!

    MockURLProtocol.setHandler(for: "/closure/data") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, expectedData)
    }

    let endpoint = Endpoint<Data>(path: "closure/data", method: .get)

    let response: Response<Data> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    switch response.result {
    case .success(let data):
      #expect(data == expectedData)
    case .failure(let error):
      Issue.record("Expected success but got error: \(error)")
    }
  }

  @Test("String success response")
  func stringSuccess() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/closure/string") }

    let expectedString = "Hello, World!"

    MockURLProtocol.setHandler(for: "/closure/string") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, expectedString.data(using: .utf8)!)
    }

    let endpoint = Endpoint<String>(path: "closure/string", method: .get)

    let response: Response<String> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    switch response.result {
    case .success(let string):
      #expect(string == expectedString)
    case .failure(let error):
      Issue.record("Expected success but got error: \(error)")
    }
  }

  @Test("Void success response")
  func voidSuccess() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/closure/void") }

    MockURLProtocol.setHandler(for: "/closure/void") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 204,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, Data())
    }

    let endpoint = Endpoint<Void>(path: "closure/void", method: .delete)

    let response: Response<Void> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    switch response.result {
    case .success:
      break
    case .failure(let error):
      Issue.record("Expected success but got error: \(error)")
    }
  }

  @Test("HTTP 404 error")
  func http404Error() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/closure/notfound") }

    MockURLProtocol.setHandler(for: "/closure/notfound") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 404,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, "Not Found".data(using: .utf8)!)
    }

    let endpoint = Endpoint<TestUser>(path: "closure/notfound", method: .get)

    let response: Response<TestUser> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    switch response.result {
    case .success:
      Issue.record("Expected error but got success")
    case .failure(let error):
      if case .error(let statusCode, _) = error {
        #expect(statusCode == 404)
      } else {
        Issue.record("Expected .error but got \(error)")
      }
    }
  }

  @Test("HTTP 500 error")
  func http500Error() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/closure/servererror") }

    MockURLProtocol.setHandler(for: "/closure/servererror") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 500,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, "Internal Server Error".data(using: .utf8)!)
    }

    let endpoint = Endpoint<TestUser>(path: "closure/servererror", method: .get)

    let response: Response<TestUser> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    switch response.result {
    case .success:
      Issue.record("Expected error but got success")
    case .failure(let error):
      if case .error(let statusCode, _) = error {
        #expect(statusCode == 500)
      } else {
        Issue.record("Expected .error but got \(error)")
      }
    }
  }

  @Test("JSON parsing failure")
  func parsingFailure() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/closure/badjson") }

    MockURLProtocol.setHandler(for: "/closure/badjson") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      return (response, "invalid json".data(using: .utf8)!)
    }

    let endpoint = Endpoint<TestUser>(path: "closure/badjson", method: .get)

    let response: Response<TestUser> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    switch response.result {
    case .success:
      Issue.record("Expected parsing error but got success")
    case .failure(let error):
      if case .parsingFailed = error {
        // Expected
      } else {
        Issue.record("Expected .parsingFailed but got \(error)")
      }
    }
  }
}
