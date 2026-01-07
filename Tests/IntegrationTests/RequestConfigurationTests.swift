import Testing
import Foundation
@testable import SmartNet

@Suite("Request Configuration Tests")
struct RequestConfigurationTests {

  @Test("POST request with JSON body")
  func postWithJSONBody() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/config/post") }

    let requestBody = TestUser(id: 0, name: "New User", email: "new@example.com")
    let responseUser = TestUser(id: 123, name: "New User", email: "new@example.com")

    MockURLProtocol.setHandler(for: "/config/post") { request in
      #expect(request.httpMethod == "POST")
      #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

      if let bodyData = request.httpBody ?? request.httpBodyStream?.readAllData() {
        let sentUser = try? JSONDecoder().decode(TestUser.self, from: bodyData)
        #expect(sentUser?.name == requestBody.name)
        #expect(sentUser?.email == requestBody.email)
      }

      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 201,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      let data = try! JSONEncoder().encode(responseUser)
      return (response, data)
    }

    let endpoint = Endpoint<TestUser>(
      path: "config/post",
      method: .post,
      body: HTTPBody(encodable: requestBody)
    )

    let response: Response<TestUser> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    switch response.result {
    case .success(let user):
      #expect(user.id == responseUser.id)
      #expect(user.name == responseUser.name)
    case .failure(let error):
      Issue.record("Expected success but got error: \(error)")
    }
  }

  @Test("Request with query parameters")
  func withQueryParameters() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/config/query") }

    MockURLProtocol.setHandler(for: "/config/query") { request in
      let urlComponents = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
      let queryItems = urlComponents?.queryItems ?? []

      #expect(queryItems.contains { $0.name == "page" && $0.value == "1" })
      #expect(queryItems.contains { $0.name == "limit" && $0.value == "10" })

      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, "[]".data(using: .utf8)!)
    }

    let endpoint = Endpoint<Data>(
      path: "config/query",
      method: .get,
      queryParameters: QueryParameters(parameters: ["page": 1, "limit": 10])
    )

    let response: Response<Data> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    #expect(response.result.isSuccess)
  }

  @Test("Request with custom headers")
  func withCustomHeaders() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/config/headers") }

    MockURLProtocol.setHandler(for: "/config/headers") { request in
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token123")
      #expect(request.value(forHTTPHeaderField: "X-Custom-Header") == "CustomValue")

      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, Data())
    }

    let endpoint = Endpoint<Data>(
      path: "config/headers",
      method: .get,
      headers: [
        "Authorization": "Bearer token123",
        "X-Custom-Header": "CustomValue"
      ]
    )

    let response: Response<Data> = await withCheckedContinuation { continuation in
      client.request(with: endpoint) { response in
        continuation.resume(returning: response)
      }
    }

    #expect(response.result.isSuccess)
  }

  @Test("PUT request updates resource")
  func putRequest() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/config/put") }

    let updatedUser = TestUser(id: 1, name: "Updated Name", email: "updated@example.com")

    MockURLProtocol.setHandler(for: "/config/put") { request in
      #expect(request.httpMethod == "PUT")

      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      let data = try! JSONEncoder().encode(updatedUser)
      return (response, data)
    }

    let endpoint = Endpoint<TestUser>(
      path: "config/put",
      method: .put,
      body: HTTPBody(encodable: updatedUser)
    )

    let user: TestUser = try await client.request(with: endpoint)
    #expect(user.name == "Updated Name")
  }

  @Test("PATCH request partially updates resource")
  func patchRequest() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/config/patch") }

    MockURLProtocol.setHandler(for: "/config/patch") { request in
      #expect(request.httpMethod == "PATCH")

      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, "{}".data(using: .utf8)!)
    }

    let endpoint = Endpoint<Data>(
      path: "config/patch",
      method: .patch,
      body: HTTPBody(dictionary: ["name": "Patched"])
    )

    let _: Data = try await client.request(with: endpoint)
  }

  @Test("DELETE request")
  func deleteRequest() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/config/delete") }

    MockURLProtocol.setHandler(for: "/config/delete") { request in
      #expect(request.httpMethod == "DELETE")

      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 204,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, Data())
    }

    let endpoint = Endpoint<Void>(path: "config/delete", method: .delete)
    let _: Void = try await client.request(with: endpoint)
  }
}
