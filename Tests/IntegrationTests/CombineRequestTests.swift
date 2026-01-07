import Testing
import Foundation
import Combine
@testable import SmartNet

@Suite("Combine Request Tests")
struct CombineRequestTests {

  @Test("Decodable success")
  func decodableSuccess() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/combine/decodable") }

    let expectedUser = TestUser(id: 2, name: "Bob Smith", email: "bob@example.com")

    MockURLProtocol.setHandler(for: "/combine/decodable") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      let data = try! JSONEncoder().encode(expectedUser)
      return (response, data)
    }

    let endpoint = Endpoint<TestUser>(path: "combine/decodable", method: .get)
    let publisher: AnyPublisher<TestUser, Error> = client.request(with: endpoint)

    let holder = CancellableHolder()

    let user: TestUser = try await withCheckedThrowingContinuation { continuation in
      let cancellable = publisher
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              continuation.resume(throwing: error)
            }
          },
          receiveValue: { user in
            continuation.resume(returning: user)
          }
        )
      Task { await holder.store(cancellable) }
    }

    #expect(user.id == expectedUser.id)
    #expect(user.name == expectedUser.name)
    #expect(user.email == expectedUser.email)
  }

  @Test("HTTP 403 error")
  func http403Error() async {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/combine/forbidden") }

    MockURLProtocol.setHandler(for: "/combine/forbidden") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 403,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, "Forbidden".data(using: .utf8)!)
    }

    let endpoint = Endpoint<TestUser>(path: "combine/forbidden", method: .get)
    let publisher: AnyPublisher<TestUser, Error> = client.request(with: endpoint)

    let holder = CancellableHolder()

    do {
      let _: TestUser = try await withCheckedThrowingContinuation { continuation in
        let cancellable = publisher
          .sink(
            receiveCompletion: { completion in
              if case .failure(let error) = completion {
                continuation.resume(throwing: error)
              }
            },
            receiveValue: { user in
              continuation.resume(returning: user)
            }
          )
        Task { await holder.store(cancellable) }
      }
      Issue.record("Expected error but got success")
    } catch let error as NetworkError {
      if case .error(let statusCode, _) = error {
        #expect(statusCode == 403)
      } else {
        Issue.record("Expected .error but got \(error)")
      }
    } catch {
      Issue.record("Unexpected error type: \(error)")
    }
  }

  @Test("Data success")
  func dataSuccess() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/combine/data") }

    let expectedData = "Raw Combine data".data(using: .utf8)!

    MockURLProtocol.setHandler(for: "/combine/data") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, expectedData)
    }

    let endpoint = Endpoint<Data>(path: "combine/data", method: .get)
    let publisher: AnyPublisher<Data, Error> = client.request(with: endpoint)

    let holder = CancellableHolder()

    let data: Data = try await withCheckedThrowingContinuation { continuation in
      let cancellable = publisher
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              continuation.resume(throwing: error)
            }
          },
          receiveValue: { data in
            continuation.resume(returning: data)
          }
        )
      Task { await holder.store(cancellable) }
    }

    #expect(data == expectedData)
  }

  @Test("String success")
  func stringSuccess() async throws {
    let (client, _) = createMockClient()
    defer { client.destroy(); MockURLProtocol.removeHandler(for: "/combine/string") }

    let expectedString = "Combine string response"

    MockURLProtocol.setHandler(for: "/combine/string") { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, expectedString.data(using: .utf8)!)
    }

    let endpoint = Endpoint<String>(path: "combine/string", method: .get)
    let publisher: AnyPublisher<String, Error> = client.request(with: endpoint)

    let holder = CancellableHolder()

    let string: String = try await withCheckedThrowingContinuation { continuation in
      let cancellable = publisher
        .sink(
          receiveCompletion: { completion in
            if case .failure(let error) = completion {
              continuation.resume(throwing: error)
            }
          },
          receiveValue: { string in
            continuation.resume(returning: string)
          }
        )
      Task { await holder.store(cancellable) }
    }

    #expect(string == expectedString)
  }
}
