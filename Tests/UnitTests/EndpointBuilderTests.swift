import Testing
import Foundation
@testable import SmartNet

@Suite("Endpoint Builder Tests")
struct EndpointBuilderTests {

  // MARK: - Factory Method Tests

  @Test("GET factory creates endpoint with correct method")
  func getFactory() {
    let endpoint: Endpoint<String> = .get("users")

    #expect(endpoint.path == "users")
    #expect(endpoint.method == .get)
    #expect(endpoint.isFullPath == false)
  }

  @Test("GET factory with full path")
  func getFactoryFullPath() {
    let endpoint: Endpoint<String> = .get("https://api.example.com/users", isFullPath: true)

    #expect(endpoint.path == "https://api.example.com/users")
    #expect(endpoint.isFullPath == true)
  }

  @Test("POST factory creates endpoint with correct method")
  func postFactory() {
    let endpoint: Endpoint<String> = .post("users")

    #expect(endpoint.path == "users")
    #expect(endpoint.method == .post)
  }

  @Test("PUT factory creates endpoint with correct method")
  func putFactory() {
    let endpoint: Endpoint<String> = .put("users/123")

    #expect(endpoint.path == "users/123")
    #expect(endpoint.method == .put)
  }

  @Test("PATCH factory creates endpoint with correct method")
  func patchFactory() {
    let endpoint: Endpoint<String> = .patch("users/123")

    #expect(endpoint.path == "users/123")
    #expect(endpoint.method == .patch)
  }

  @Test("DELETE factory creates endpoint with correct method")
  func deleteFactory() {
    let endpoint: Endpoint<String> = .delete("users/123")

    #expect(endpoint.path == "users/123")
    #expect(endpoint.method == .delete)
  }

  @Test("HEAD factory creates endpoint with correct method")
  func headFactory() {
    let endpoint: Endpoint<String> = .head("users")

    #expect(endpoint.path == "users")
    #expect(endpoint.method == .head)
  }

  @Test("OPTIONS factory creates endpoint with correct method")
  func optionsFactory() {
    let endpoint: Endpoint<String> = .options("users")

    #expect(endpoint.path == "users")
    #expect(endpoint.method == .options)
  }

  // MARK: - Header Tests

  @Test("headers() sets headers")
  func headersModifier() {
    let endpoint: Endpoint<String> = .get("users")
      .headers(["Authorization": "Bearer token"])

    #expect(endpoint.headers["Authorization"] == "Bearer token")
  }

  @Test("headers() replaces existing headers")
  func headersReplaces() {
    let endpoint: Endpoint<String> = .get("users")
      .headers(["X-First": "first"])
      .headers(["X-Second": "second"])

    #expect(endpoint.headers["X-First"] == nil)
    #expect(endpoint.headers["X-Second"] == "second")
  }

  @Test("addingHeaders() merges with existing")
  func addingHeadersMerges() {
    let endpoint: Endpoint<String> = .get("users")
      .headers(["X-First": "first"])
      .addingHeaders(["X-Second": "second"])

    #expect(endpoint.headers["X-First"] == "first")
    #expect(endpoint.headers["X-Second"] == "second")
  }

  @Test("addingHeaders() overwrites duplicates")
  func addingHeadersOverwrites() {
    let endpoint: Endpoint<String> = .get("users")
      .headers(["X-Key": "old"])
      .addingHeaders(["X-Key": "new"])

    #expect(endpoint.headers["X-Key"] == "new")
  }

  @Test("header() sets single header")
  func singleHeader() {
    let endpoint: Endpoint<String> = .get("users")
      .header("Authorization", "Bearer token")

    #expect(endpoint.headers["Authorization"] == "Bearer token")
  }

  @Test("header() can be chained")
  func headerChained() {
    let endpoint: Endpoint<String> = .get("users")
      .header("Authorization", "Bearer token")
      .header("Accept", "application/json")

    #expect(endpoint.headers["Authorization"] == "Bearer token")
    #expect(endpoint.headers["Accept"] == "application/json")
  }

  // MARK: - Query Parameter Tests

  @Test("query() with dictionary sets parameters")
  func queryDictionary() {
    let endpoint: Endpoint<String> = .get("users")
      .query(["page": 1, "limit": 10])

    #expect(endpoint.queryParameters != nil)
  }

  @Test("query() with QueryParameters sets parameters")
  func queryParameters() {
    let params = QueryParameters(parameters: ["search": "test"])
    let endpoint: Endpoint<String> = .get("users")
      .query(params)

    #expect(endpoint.queryParameters != nil)
  }

  // MARK: - Body Tests

  @Test("body() with dictionary sets body")
  func bodyDictionary() {
    let endpoint: Endpoint<String> = .post("users")
      .body(["name": "John", "email": "john@example.com"])

    #expect(endpoint.body != nil)
    #expect(endpoint.body?.data != nil)
  }

  @Test("body() with dictionary and custom encoding")
  func bodyDictionaryFormEncoded() {
    let endpoint: Endpoint<String> = .post("users")
      .body(["name": "John"], encoding: .formUrlEncodedAscii)

    #expect(endpoint.body != nil)
  }

  @Test("body() with Encodable sets body")
  func bodyEncodable() {
    struct User: Encodable {
      let name: String
      let email: String
    }

    let user = User(name: "John", email: "john@example.com")
    let endpoint: Endpoint<String> = .post("users")
      .body(user)

    #expect(endpoint.body != nil)
    #expect(endpoint.body?.data != nil)
  }

  @Test("body() with Encodable and custom encoder")
  func bodyEncodableCustomEncoder() {
    struct User: Encodable {
      let userName: String
    }

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    let user = User(userName: "John")
    let endpoint: Endpoint<String> = .post("users")
      .body(user, encoder: encoder)

    #expect(endpoint.body != nil)

    if let data = endpoint.body?.data,
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      #expect(json["user_name"] as? String == "John")
    }
  }

  @Test("body() with HTTPBody sets body directly")
  func bodyHTTPBody() {
    let httpBody = HTTPBody(dictionary: ["key": "value"])!
    let endpoint: Endpoint<String> = .post("users")
      .body(httpBody)

    #expect(endpoint.body != nil)
  }

  // MARK: - Configuration Tests

  @Test("useEndpointHeadersOnly() sets flag")
  func useEndpointHeadersOnly() {
    let endpoint: Endpoint<String> = .get("users")
      .useEndpointHeadersOnly()

    #expect(endpoint.useEndpointHeaderOnly == true)
  }

  @Test("useEndpointHeadersOnly(false) clears flag")
  func useEndpointHeadersOnlyFalse() {
    let endpoint: Endpoint<String> = .get("users")
      .useEndpointHeadersOnly()
      .useEndpointHeadersOnly(false)

    #expect(endpoint.useEndpointHeaderOnly == false)
  }

  @Test("allowMiddlewares() sets flag")
  func allowMiddlewares() {
    let endpoint: Endpoint<String> = .get("users")
      .allowMiddlewares(false)

    #expect(endpoint.allowMiddlewares == false)
  }

  @Test("withoutMiddlewares() disables middlewares")
  func withoutMiddlewares() {
    let endpoint: Endpoint<String> = .get("users")
      .withoutMiddlewares()

    #expect(endpoint.allowMiddlewares == false)
  }

  @Test("debug() enables debug logging")
  func debugEnabled() {
    let endpoint: Endpoint<String> = .get("users")
      .debug()

    #expect(endpoint.debugRequest == true)
  }

  @Test("debug(false) disables debug logging")
  func debugDisabled() {
    let endpoint: Endpoint<String> = .get("users")
      .debug()
      .debug(false)

    #expect(endpoint.debugRequest == false)
  }

  // MARK: - Retry Policy Tests

  @Test("retry() sets retry policy")
  func retryPolicy() {
    let policy = ExponentialBackoffRetryPolicy(maxRetries: 5)
    let endpoint: Endpoint<String> = .get("users")
      .retry(policy)

    #expect(endpoint.retryPolicy != nil)
    #expect(endpoint.retryPolicy?.maxRetries == 5)
  }

  @Test("noRetry() disables retries")
  func noRetry() {
    let endpoint: Endpoint<String> = .get("users")
      .noRetry()

    #expect(endpoint.retryPolicy != nil)
    #expect(endpoint.retryPolicy?.maxRetries == 0)
  }

  // MARK: - Chaining Tests

  @Test("All modifiers can be chained")
  func fullChaining() {
    struct CreateUser: Encodable {
      let name: String
    }

    let endpoint: Endpoint<String> = .post("users")
      .headers(["Content-Type": "application/json"])
      .header("Authorization", "Bearer token")
      .query(["include": "profile"])
      .body(CreateUser(name: "John"))
      .debug()
      .retry(ExponentialBackoffRetryPolicy(maxRetries: 2))

    #expect(endpoint.path == "users")
    #expect(endpoint.method == .post)
    #expect(endpoint.headers["Content-Type"] == "application/json")
    #expect(endpoint.headers["Authorization"] == "Bearer token")
    #expect(endpoint.queryParameters != nil)
    #expect(endpoint.body != nil)
    #expect(endpoint.debugRequest == true)
    #expect(endpoint.retryPolicy?.maxRetries == 2)
  }

  @Test("Modifiers don't mutate original endpoint")
  func immutability() {
    let original: Endpoint<String> = .get("users")
    let modified = original.headers(["X-Test": "value"])

    #expect(original.headers.isEmpty)
    #expect(modified.headers["X-Test"] == "value")
  }

  // MARK: - URL Request Generation Tests

  @Test("Builder endpoint generates valid URL request")
  func urlRequestGeneration() throws {
    let endpoint: Endpoint<String> = .get("users/123")
      .headers(["Authorization": "Bearer token"])
      .query(["include": "profile"])

    let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
    let request = try endpoint.urlRequest(with: config)

    #expect(request.httpMethod == "GET")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    #expect(request.url?.absoluteString.contains("include=profile") == true)
  }

  @Test("POST endpoint generates request with body")
  func postUrlRequestGeneration() throws {
    let endpoint: Endpoint<String> = .post("users")
      .body(["name": "John"])

    let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
    let request = try endpoint.urlRequest(with: config)

    #expect(request.httpMethod == "POST")
    #expect(request.httpBody != nil)
  }
}
