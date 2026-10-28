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

  @Test("Void request passes HTTP errors through with response metadata")
  func voidHTTPErrorPassesThrough() async {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/closure/voiderror") }

    MockURLProtocol.setHandler(for: "/closure/voiderror") { request in
      (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data("boom".utf8))
    }

    let endpoint = Endpoint<Void>(path: "closure/voiderror", method: .delete)
    let response: Response<Void> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { continuation.resume(returning: $0) }
    }

    #expect(response.error as? NetworkError == .error(statusCode: 500, data: Data("boom".utf8)))
    #expect(response.statusCode == 500)
    #expect(response.request?.url?.path == "/closure/voiderror")
  }

  @Test("Completion runs on the requested queue for success and failure")
  func completionRunsOnRequestedQueue() async {
    let (client, _) = createMockClient()
    defer {
      client.destroy()
      MockURLProtocol.removeHandler(for: "/closure/queue-ok")
      MockURLProtocol.removeHandler(for: "/closure/queue-fail")
    }

    MockURLProtocol.setHandler(for: "/closure/queue-ok") { request in
      (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("ok".utf8))
    }
    MockURLProtocol.setHandler(for: "/closure/queue-fail") { request in
      (HTTPURLResponse(url: request.url!, statusCode: 418, httpVersion: nil, headerFields: nil)!, Data())
    }

    let key = DispatchSpecificKey<String>()
    let queue = DispatchQueue(label: "closure.queue.test")
    queue.setSpecific(key: key, value: "custom")

    for path in ["closure/queue-ok", "closure/queue-fail"] {
      let (marker, statusCode): (String?, Int) = await withCheckedContinuation { continuation in
        client.request(with: Endpoint<Data>(path: path, method: .get), queue: queue) { response in
          continuation.resume(returning: (DispatchQueue.getSpecific(key: key), response.statusCode))
        }
      }
      #expect(marker == "custom")
      #expect(statusCode == (path.hasSuffix("ok") ? 200 : 418))
    }
  }
}
