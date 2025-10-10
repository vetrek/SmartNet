import XCTest
@testable import SmartNet

final class DebugRequestTests: XCTestCase {

  func testRequestableDefaultDebugRequestIsFalse() {
    let request = StubRequest()
    XCTAssertFalse(request.debugRequest)
  }

  func testEndpointDebugRequestDefaultsToFalse() {
    let endpoint = Endpoint<Data>(path: "users")
    XCTAssertFalse(endpoint.debugRequest)
  }

  func testEndpointDebugRequestCanBeEnabled() {
    let endpoint = Endpoint<Data>(path: "users", debugRequest: true)
    XCTAssertTrue(endpoint.debugRequest)
  }

  func testDownloadEndpointDebugRequest() {
    let endpoint = DownloadEndpoint(path: "file.zip", debugRequest: true)
    XCTAssertTrue(endpoint.debugRequest)
  }

  func testMultipartFormEndpointDebugRequest() {
    let form = MultipartFormData()
    let endpoint = MultipartFormEndpoint<Data>(path: "upload", form: form, debugRequest: true)
    XCTAssertTrue(endpoint.debugRequest)
  }

  func testDownloadTaskCapturesEndpointDebugIntent() throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let endpoint = DownloadEndpoint(path: "file.zip", debugRequest: true)
    let session = URLSession(configuration: .ephemeral)

    let task = try DownloadTask(
      session: session,
      endpoint: endpoint,
      config: config,
      destination: nil
    )

    XCTAssertTrue(task.shouldDebug)
  }
}

// MARK: - Test helpers

private struct StubRequest: Requestable {
  typealias Response = Data

  var path: String { "/stub" }
  var isFullPath: Bool { true }
  var method: HTTPMethod { .get }
  var headers: [String: String] { [:] }
  var useEndpointHeaderOnly: Bool { false }
  var queryParameters: QueryParameters? { nil }
  var body: HTTPBody? { nil }
  var form: MultipartFormData? { nil }
  var allowMiddlewares: Bool { false }
}
