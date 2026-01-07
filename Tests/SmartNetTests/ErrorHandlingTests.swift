import Testing
import Foundation
@testable import SmartNet

@Suite("Error Handling Tests")
struct ErrorHandlingTests {

  @Test("Empty response for Decodable fails with parsing error")
  func emptyResponseForDecodable() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/error/empty") }

    MockURLProtocol.setHandler(for: "/error/empty") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, Data())
    }

    let endpoint = Endpoint<TestUser>(path: "error/empty", method: .get)

    let response: Response<TestUser> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    switch response.result {
    case .success:
      Issue.record("Expected error for empty response")
    case .failure(let error):
      if case .parsingFailed = error {
        // Expected
      } else if case .emptyResponse = error {
        // Also acceptable
      } else {
        Issue.record("Expected parsing or empty response error but got \(error)")
      }
    }
  }

  @Test("Empty response for Void succeeds")
  func emptyResponseForVoidSucceeds() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/error/voidempty") }

    MockURLProtocol.setHandler(for: "/error/voidempty") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, Data())
    }

    let endpoint = Endpoint<Void>(path: "error/voidempty", method: .delete)

    let response: Response<Void> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    #expect(response.result.isSuccess, "Empty response should succeed for Void type")
  }

  @Test("Network unreachable returns network failure")
  func networkUnreachable() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/error/unreachable") }

    MockURLProtocol.setHandler(for: "/error/unreachable") { request in
      throw URLError(.notConnectedToInternet)
    }

    let endpoint = Endpoint<Data>(path: "error/unreachable", method: .get)

    let response: Response<Data> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    switch response.result {
    case .success:
      Issue.record("Expected network error but got success")
    case .failure(let error):
      if case .networkFailure = error {
        // Expected
      } else if case .generic(let underlyingError) = error,
                (underlyingError as? URLError)?.code == .notConnectedToInternet {
        // Also acceptable
      } else {
        Issue.record("Expected network failure but got \(error)")
      }
    }
  }

  @Test("Cancelled request returns cancelled error")
  func cancelledRequest() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/error/cancelled") }

    MockURLProtocol.setHandler(for: "/error/cancelled") { request in
      throw URLError(.cancelled)
    }

    let endpoint = Endpoint<Data>(path: "error/cancelled", method: .get)

    let response: Response<Data> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    switch response.result {
    case .success:
      Issue.record("Expected cancelled error but got success")
    case .failure(let error):
      if case .cancelled = error {
        // Expected
      } else if case .generic(let underlyingError) = error,
                (underlyingError as? URLError)?.code == .cancelled {
        // Also acceptable
      } else {
        Issue.record("Expected cancelled but got \(error)")
      }
    }
  }

  @Test("HTTP 400 bad request error")
  func http400Error() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/error/badrequest") }

    let errorMessage = "Bad Request"

    MockURLProtocol.setHandler(for: "/error/badrequest") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 400,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, errorMessage.data(using: .utf8)!)
    }

    let endpoint = Endpoint<TestUser>(path: "error/badrequest", method: .post)

    do {
      let _: TestUser = try await client.request(with: endpoint)
      Issue.record("Expected error but got success")
    } catch let error as NetworkError {
      if case .error(let statusCode, let data) = error {
        #expect(statusCode == 400)
        if let data = data, let message = String(data: data, encoding: .utf8) {
          #expect(message == errorMessage)
        }
      } else {
        Issue.record("Expected .error but got \(error)")
      }
    }
  }

  @Test("HTTP 503 service unavailable error")
  func http503Error() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/error/unavailable") }

    MockURLProtocol.setHandler(for: "/error/unavailable") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 503,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, "Service Unavailable".data(using: .utf8)!)
    }

    let endpoint = Endpoint<Data>(path: "error/unavailable", method: .get)

    do {
      let _: Data = try await client.request(with: endpoint)
      Issue.record("Expected error but got success")
    } catch let error as NetworkError {
      if case .error(let statusCode, _) = error {
        #expect(statusCode == 503)
      } else {
        Issue.record("Expected .error but got \(error)")
      }
    }
  }

  @Test("Error data is preserved in response")
  func errorDataPreserved() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/error/preserved") }

    let errorJson = """
    {"error": "validation_failed", "fields": ["email"]}
    """.data(using: .utf8)!

    MockURLProtocol.setHandler(for: "/error/preserved") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 422,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      return (response, errorJson)
    }

    let endpoint = Endpoint<TestUser>(path: "error/preserved", method: .post)

    let response: Response<TestUser> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    switch response.result {
    case .success:
      Issue.record("Expected error but got success")
    case .failure(let error):
      if case .error(let statusCode, let data) = error {
        #expect(statusCode == 422)
        #expect(data == errorJson)
      } else {
        Issue.record("Expected .error with data but got \(error)")
      }
    }
  }
}
