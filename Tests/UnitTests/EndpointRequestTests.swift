import Testing
import Foundation
@testable import SmartNet

@Suite("Endpoint Request Tests")
struct EndpointRequestTests {

  private func createConfig() -> NetworkConfiguration {
    NetworkConfiguration(
      baseURL: URL(string: "https://example.com/api")!,
      headers: ["Authorization": "Bearer global-token"],
      queryParameters: ["lang": "en"],
      bodyParameters: ["globalKey": "globalValue"]
    )
  }

  @Test("URL request builds URL using base path and query parameters")
  func urlRequestBuildsUrlUsingBasePathAndQueryParameters() throws {
    let config = createConfig()

    let endpoint = Endpoint<Data>(
      path: "/users/42 profile",
      method: .get,
      queryParameters: QueryParameters(parameters: ["include": "details"])
    )

    let request = try endpoint.urlRequest(with: config)
    let url = try #require(request.url)
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

    #expect(components.scheme == "https")
    #expect(components.host == "example.com")
    #expect(components.path == "/api/users/42 profile")
    #expect(components.percentEncodedPath == "/api/users/42%20profile")

    let queryItems = components.queryItems ?? []
    let queryDictionary = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
    #expect(queryDictionary["include"] == "details")
    #expect(queryDictionary["lang"] == "en")
  }

  @Test("Headers merge favor endpoint values")
  func headersMergeFavorEndpointValues() throws {
    let config = createConfig()

    let endpoint = Endpoint<Data>(
      path: "users",
      method: .get,
      headers: [
        "Authorization": "Bearer endpoint-token",
        "X-Custom": "endpoint"
      ]
    )

    let request = try endpoint.urlRequest(with: config)

    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer endpoint-token")
    #expect(request.value(forHTTPHeaderField: "X-Custom") == "endpoint")
    #expect(request.value(forHTTPHeaderField: "Accept") == nil)
  }

  @Test("Headers skip config when useEndpointHeaderOnly is true")
  func headersSkipConfigWhenUseEndpointHeaderOnlyIsTrue() throws {
    let config = createConfig()

    let endpoint = Endpoint<Data>(
      path: "users",
      method: .get,
      headers: ["X-Only": "endpoint"],
      useEndpointHeaderOnly: true
    )

    let request = try endpoint.urlRequest(with: config)

    #expect(request.value(forHTTPHeaderField: "X-Only") == "endpoint")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
  }

  @Test("Body merges config body parameters")
  func bodyMergesConfigBodyParameters() throws {
    let config = createConfig()

    let endpoint = Endpoint<Data>(
      path: "users",
      method: .post,
      body: HTTPBody(dictionary: ["localKey": "localValue"])!
    )

    let request = try endpoint.urlRequest(with: config)
    let bodyData = try #require(request.httpBody)
    let payload = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]

    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(payload?["localKey"] as? String == "localValue")
    #expect(payload?["globalKey"] as? String == "globalValue")
  }

  @Test("Body falls back to config body when endpoint body is nil")
  func bodyFallsBackToConfigBodyWhenEndpointBodyIsNil() throws {
    let config = createConfig()

    let endpoint = Endpoint<Data>(
      path: "users",
      method: .post
    )

    let request = try endpoint.urlRequest(with: config)
    let bodyData = try #require(request.httpBody)
    let payload = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]

    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(payload?["globalKey"] as? String == "globalValue")
  }

  @Test("Full path ignores base URL path")
  func fullPathIgnoresBaseURLPath() throws {
    // Use a config without query parameters to test just the path behavior
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com/api")!)

    let endpoint = Endpoint<Data>(
      path: "https://other.com/external",
      isFullPath: true,
      method: .get
    )

    let request = try endpoint.urlRequest(with: config)

    #expect(request.url?.absoluteString == "https://other.com/external")
  }

  @Test("HTTP method is correctly set")
  func httpMethodIsCorrectlySet() throws {
    let config = createConfig()

    let methods: [HTTPMethod] = [.get, .post, .put, .patch, .delete]

    for method in methods {
      let endpoint = Endpoint<Data>(path: "test", method: method)
      let request = try endpoint.urlRequest(with: config)
      #expect(request.httpMethod == method.rawValue.uppercased())
    }
  }

  @Test("Path leading slash and query composition produce exact URL")
  func pathLeadingSlashAndQueryComposition() throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com/api")!, queryParameters: ["lang": "en"])
    let cases: [(String, QueryParameters?, String)] = [
      ("/users", nil, "https://example.com/api/users?lang=en"),
      ("users", nil, "https://example.com/api/users?lang=en"),
      ("/", nil, "https://example.com/api/?lang=en"),
      ("", nil, "https://example.com/api/?lang=en"),
      ("//double", nil, "https://example.com/api//double?lang=en"),
      ("/ñandú/x", nil, "https://example.com/api/%C3%B1and%C3%BA/x?lang=en"),
      ("/👍/x", nil, "https://example.com/api/%F0%9F%91%8D/x?lang=en"),
      ("/a?b=1", QueryParameters(parameters: ["q": 2]), "https://example.com/api/a?b=1&q=2&lang=en")
    ]

    for (path, query, expected) in cases {
      let request = try Endpoint<Data>(path: path, queryParameters: query).urlRequest(with: config)
      #expect(request.url?.absoluteString == expected, "\(path)")
    }
  }
}
