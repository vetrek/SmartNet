import Testing
import Foundation
@testable import SmartNet

@Suite("ApiClient Middleware Tests", .serialized)
struct ApiClientMiddlewareTests {

  @Test("Prepare request applies global and path middlewares")
  func prepareRequestAppliesGlobalAndPathMiddlewares() throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    let globalMiddleware = TestMiddleware(
      pathComponent: "/",
      preRequestHandler: { request in
        request.addValue("global", forHTTPHeaderField: "X-Test-Header")
      }
    )

    let pathMiddleware = TestMiddleware(
      pathComponent: "users",
      preRequestHandler: { request in
        request.addValue("path", forHTTPHeaderField: "X-Path-Header")
      }
    )

    client.addMiddleware(globalMiddleware)
    client.addMiddleware(pathMiddleware)

    let endpoint = Endpoint<Data>(
      path: "users",
      method: .get
    )

    let request = try client.prepareRequest(for: endpoint)

    #expect(request.value(forHTTPHeaderField: "X-Test-Header") == "global")
    #expect(request.value(forHTTPHeaderField: "X-Path-Header") == "path")
  }

  @Test("Prepare request skips middlewares when disabled")
  func prepareRequestSkipsMiddlewaresWhenDisabled() throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    let middleware = TestMiddleware(
      pathComponent: "/",
      preRequestHandler: { request in
        request.addValue("value", forHTTPHeaderField: "X-Should-Not-Exist")
      }
    )

    client.addMiddleware(middleware)

    let endpoint = Endpoint<Data>(
      path: "users",
      method: .get,
      allowMiddlewares: false
    )

    let request = try client.prepareRequest(for: endpoint)

    #expect(request.value(forHTTPHeaderField: "X-Should-Not-Exist") == nil)
  }

  @Test("Middleware groups separates global and path targets")
  func middlewareGroupsSeparatesGlobalAndPathTargets() throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    let globalMiddleware = TestMiddleware(pathComponent: "/")
    let pathMiddleware = TestMiddleware(pathComponent: "users")
    client.addMiddleware(globalMiddleware)
    client.addMiddleware(pathMiddleware)

    let url = URL(string: "https://example.com/users/profile")!
    let groups = client.middlewareGroups(for: url)

    #expect(groups.global.count == 1)
    #expect(groups.path.count == 1)
    #expect(groups.global.first?.id == globalMiddleware.id)
    #expect(groups.path.first?.id == pathMiddleware.id)
  }

  @Test("Should retry after post response returns true when middleware requests retry")
  func shouldRetryAfterPostResponseReturnsTrueWhenMiddlewareRequestsRetry() async throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    let retryMiddleware = TestMiddleware(
      pathComponent: "/",
      postResponseHandler: { _, _, _ in
        .retryRequest
      }
    )

    let shouldRetry = try await client.shouldRetryAfterPostResponse(
      [retryMiddleware],
      data: nil,
      response: nil,
      error: nil
    )

    #expect(shouldRetry == true)
  }

  @Test("Should retry after post response returns false when middlewares continue")
  func shouldRetryAfterPostResponseReturnsFalseWhenMiddlewaresContinue() async throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    let middleware = TestMiddleware(
      pathComponent: "/",
      postResponseHandler: { _, _, _ in
        .next
      }
    )

    let shouldRetry = try await client.shouldRetryAfterPostResponse(
      [middleware],
      data: nil,
      response: nil,
      error: nil
    )

    #expect(shouldRetry == false)
  }

  @Test("Remove middleware by path component")
  func removeMiddlewareByPathComponent() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    let middleware1 = TestMiddleware(pathComponent: "users")
    let middleware2 = TestMiddleware(pathComponent: "posts")

    client.addMiddleware(middleware1)
    client.addMiddleware(middleware2)

    client.removeMiddleware(for: "users")

    let url = URL(string: "https://example.com/users/1")!
    let groups = client.middlewareGroups(for: url)

    #expect(groups.path.isEmpty)
  }

  @Test("Remove specific middleware instance")
  func removeSpecificMiddlewareInstance() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    let middleware1 = TestMiddleware(pathComponent: "/")
    let middleware2 = TestMiddleware(pathComponent: "/")

    client.addMiddleware(middleware1)
    client.addMiddleware(middleware2)

    client.removeMiddleware(middleware1)

    let url = URL(string: "https://example.com/test")!
    let groups = client.middlewareGroups(for: url)

    #expect(groups.global.count == 1)
    #expect(groups.global.first?.id == middleware2.id)
  }
}

// MARK: - Test Helpers

private struct TestMiddleware: MiddlewareProtocol {
  let id = UUID()
  let pathComponent: String
  private let preRequestHandler: ((inout URLRequest) throws -> Void)?
  private let postResponseHandler: ((Data?, URLResponse?, Error?) async throws -> ApiClient.MiddlewarePostRequestResult)?

  init(
    pathComponent: String,
    preRequestHandler: ((inout URLRequest) throws -> Void)? = nil,
    postResponseHandler: ((Data?, URLResponse?, Error?) async throws -> ApiClient.MiddlewarePostRequestResult)? = nil
  ) {
    self.pathComponent = pathComponent
    self.preRequestHandler = preRequestHandler
    self.postResponseHandler = postResponseHandler
  }

  func preRequest(_ request: inout URLRequest) throws {
    try preRequestHandler?(&request)
  }

  func postResponse(
    data: Data?,
    response: URLResponse?,
    error: Error?
  ) async throws -> ApiClient.MiddlewarePostRequestResult {
    if let handler = postResponseHandler {
      return try await handler(data, response, error)
    }
    return .next
  }
}
