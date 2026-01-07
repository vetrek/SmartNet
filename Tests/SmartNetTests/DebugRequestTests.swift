import Testing
import Foundation
@testable import SmartNet

@Suite("Debug Request Tests")
struct DebugRequestTests {

  @Test("Requestable default debugRequest is false")
  func requestableDefaultDebugRequestIsFalse() {
    let request = StubRequest()
    #expect(request.debugRequest == false)
  }

  @Test("Endpoint debugRequest defaults to false")
  func endpointDebugRequestDefaultsToFalse() {
    let endpoint = Endpoint<Data>(path: "users")
    #expect(endpoint.debugRequest == false)
  }

  @Test("Endpoint debugRequest can be enabled")
  func endpointDebugRequestCanBeEnabled() {
    let endpoint = Endpoint<Data>(path: "users", debugRequest: true)
    #expect(endpoint.debugRequest == true)
  }

  @Test("Download endpoint debugRequest")
  func downloadEndpointDebugRequest() {
    let endpoint = DownloadEndpoint(path: "file.zip", debugRequest: true)
    #expect(endpoint.debugRequest == true)
  }

  @Test("Multipart form endpoint debugRequest")
  func multipartFormEndpointDebugRequest() {
    let form = MultipartFormData()
    let endpoint = MultipartFormEndpoint<Data>(path: "upload", form: form, debugRequest: true)
    #expect(endpoint.debugRequest == true)
  }

  @Test("Download task captures endpoint debug intent")
  func downloadTaskCapturesEndpointDebugIntent() throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let endpoint = DownloadEndpoint(path: "file.zip", debugRequest: true)
    let session = URLSession(configuration: .ephemeral)

    let task = try DownloadTask(
      session: session,
      endpoint: endpoint,
      config: config,
      destination: nil
    )

    #expect(task.shouldDebug == true)
  }

  @Test("Download task debug is false by default")
  func downloadTaskDebugIsFalseByDefault() throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let endpoint = DownloadEndpoint(path: "file.zip")
    let session = URLSession(configuration: .ephemeral)

    let task = try DownloadTask(
      session: session,
      endpoint: endpoint,
      config: config,
      destination: nil
    )

    #expect(task.shouldDebug == false)
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
