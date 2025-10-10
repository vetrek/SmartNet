import XCTest
@testable import SmartNet

final class EndpointRequestTests: XCTestCase {

  private var config: NetworkConfiguration!

  override func setUp() {
    super.setUp()
    config = NetworkConfiguration(
      baseURL: URL(string: "https://example.com/api")!,
      headers: ["Authorization": "Bearer global-token"],
      queryParameters: ["lang": "en"],
      bodyParameters: ["globalKey": "globalValue"]
    )
  }

  override func tearDown() {
    config = nil
    super.tearDown()
  }

  func testUrlRequestBuildsUrlUsingBasePathAndQueryParameters() throws {
    let endpoint = Endpoint<Data>(
      path: "/users/42 profile",
      method: .get,
      queryParameters: QueryParameters(parameters: ["include": "details"])
    )

    let request = try endpoint.urlRequest(with: config)
    let components = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)

    XCTAssertEqual(components?.scheme, "https")
    XCTAssertEqual(components?.host, "example.com")
    XCTAssertEqual(components?.path, "/api/users/42 profile")
    XCTAssertEqual(components?.percentEncodedPath, "/api/users/42%20profile")

    let queryItems = components?.queryItems ?? []
    let queryDictionary = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
    XCTAssertEqual(queryDictionary["include"], "details")
    XCTAssertEqual(queryDictionary["lang"], "en")
  }

  func testHeadersMergeFavorEndpointValues() throws {
    let endpoint = Endpoint<Data>(
      path: "users",
      method: .get,
      headers: [
        "Authorization": "Bearer endpoint-token",
        "X-Custom": "endpoint"
      ]
    )

    let request = try endpoint.urlRequest(with: config)

    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer endpoint-token")
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom"), "endpoint")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), nil)
  }

  func testHeadersSkipConfigWhenUseEndpointHeaderOnlyIsTrue() throws {
    let endpoint = Endpoint<Data>(
      path: "users",
      method: .get,
      headers: ["X-Only": "endpoint"],
      useEndpointHeaderOnly: true
    )

    let request = try endpoint.urlRequest(with: config)

    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Only"), "endpoint")
    XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
  }

  func testBodyMergesConfigBodyParameters() throws {
    let endpoint = Endpoint<Data>(
      path: "users",
      method: .post,
      body: HTTPBody(dictionary: ["localKey": "localValue"])!
    )

    let request = try endpoint.urlRequest(with: config)
    let bodyData = try XCTUnwrap(request.httpBody)
    let payload = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]

    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertEqual(payload?["localKey"] as? String, "localValue")
    XCTAssertEqual(payload?["globalKey"] as? String, "globalValue")
  }

  func testBodyFallsBackToConfigBodyWhenEndpointBodyIsNil() throws {
    let endpoint = Endpoint<Data>(
      path: "users",
      method: .post
    )

    let request = try endpoint.urlRequest(with: config)
    let bodyData = try XCTUnwrap(request.httpBody)
    let payload = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]

    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertEqual(payload?["globalKey"] as? String, "globalValue")
  }
}
