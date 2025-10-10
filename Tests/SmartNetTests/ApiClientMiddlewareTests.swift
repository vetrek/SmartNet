import XCTest
@testable import SmartNet

final class ApiClientMiddlewareTests: XCTestCase {

  private var config: NetworkConfiguration!
  private var client: ApiClient!

  override func setUp() {
    super.setUp()
    config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    client = ApiClient(config: config)
  }

  override func tearDown() {
    client.destroy()
    client = nil
    config = nil
    super.tearDown()
  }

  func testPrepareRequestAppliesGlobalAndPathMiddlewares() throws {
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

    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Test-Header"), "global")
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Path-Header"), "path")
  }

  func testPrepareRequestSkipsMiddlewaresWhenDisabled() throws {
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

    XCTAssertNil(request.value(forHTTPHeaderField: "X-Should-Not-Exist"))
  }

  func testMiddlewareGroupsSeparatesGlobalAndPathTargets() throws {
    let globalMiddleware = TestMiddleware(pathComponent: "/")
    let pathMiddleware = TestMiddleware(pathComponent: "users")
    client.addMiddleware(globalMiddleware)
    client.addMiddleware(pathMiddleware)

    let url = URL(string: "https://example.com/users/profile")!
    let groups = client.middlewareGroups(for: url)

    XCTAssertEqual(groups.global.count, 1)
    XCTAssertEqual(groups.path.count, 1)
    XCTAssertEqual(groups.global.first?.id, globalMiddleware.id)
    XCTAssertEqual(groups.path.first?.id, pathMiddleware.id)
  }

  func testShouldRetryAfterPostResponseReturnsTrueWhenMiddlewareRequestsRetry() async throws {
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

    XCTAssertTrue(shouldRetry)
  }

  func testShouldRetryAfterPostResponseReturnsFalseWhenMiddlewaresContinue() async throws {
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

    XCTAssertFalse(shouldRetry)
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
