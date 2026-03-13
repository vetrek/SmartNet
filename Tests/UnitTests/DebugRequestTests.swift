import Testing
import Foundation
@testable import SmartNet

@Suite("Debug Request Tests")
struct DebugRequestTests {

  @Test("Requestable default debugRequest is nil")
  func requestableDefaultDebugRequestIsNil() {
    let request = StubRequest()
    #expect(request.debugRequest == nil)
  }

  @Test("Endpoint debugRequest defaults to nil")
  func endpointDebugRequestDefaultsToNil() {
    let endpoint = Endpoint<Data>(path: "users")
    #expect(endpoint.debugRequest == nil)
  }

  @Test("Endpoint debugRequest can be enabled")
  func endpointDebugRequestCanBeEnabled() {
    let endpoint = Endpoint<Data>(path: "users", debugRequest: true)
    #expect(endpoint.debugRequest == true)
  }

  @Test("Endpoint debugRequest can be explicitly disabled")
  func endpointDebugRequestCanBeDisabled() {
    let endpoint = Endpoint<Data>(path: "users", debugRequest: false)
    #expect(endpoint.debugRequest == false)
  }

  @Test("Download endpoint debugRequest defaults to nil")
  func downloadEndpointDefaultsToNil() {
    let endpoint = DownloadEndpoint(path: "file.zip")
    #expect(endpoint.debugRequest == nil)
  }

  @Test("Download endpoint debugRequest can be enabled")
  func downloadEndpointDebugRequestEnabled() {
    let endpoint = DownloadEndpoint(path: "file.zip", debugRequest: true)
    #expect(endpoint.debugRequest == true)
  }

  @Test("Download endpoint debugRequest can be explicitly disabled")
  func downloadEndpointDebugRequestDisabled() {
    let endpoint = DownloadEndpoint(path: "file.zip", debugRequest: false)
    #expect(endpoint.debugRequest == false)
  }

  @Test("Multipart form endpoint debugRequest defaults to nil")
  func multipartFormEndpointDefaultsToNil() {
    let form = MultipartFormData()
    let endpoint = MultipartFormEndpoint<Data>(path: "upload", form: form)
    #expect(endpoint.debugRequest == nil)
  }

  @Test("Multipart form endpoint debugRequest can be enabled")
  func multipartFormEndpointDebugRequest() {
    let form = MultipartFormData()
    let endpoint = MultipartFormEndpoint<Data>(path: "upload", form: form, debugRequest: true)
    #expect(endpoint.debugRequest == true)
  }

  @Test("Multipart form endpoint debugRequest can be explicitly disabled")
  func multipartFormEndpointDebugRequestDisabled() {
    let form = MultipartFormData()
    let endpoint = MultipartFormEndpoint<Data>(path: "upload", form: form, debugRequest: false)
    #expect(endpoint.debugRequest == false)
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

  @Test("Download task debug is nil by default")
  func downloadTaskDebugIsNilByDefault() throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let endpoint = DownloadEndpoint(path: "file.zip")
    let session = URLSession(configuration: .ephemeral)

    let task = try DownloadTask(
      session: session,
      endpoint: endpoint,
      config: config,
      destination: nil
    )

    #expect(task.shouldDebug == nil)
  }

  @Test("Download task captures explicit false")
  func downloadTaskCapturesExplicitFalse() throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://example.com")!)
    let endpoint = DownloadEndpoint(path: "file.zip", debugRequest: false)
    let session = URLSession(configuration: .ephemeral)

    let task = try DownloadTask(
      session: session,
      endpoint: endpoint,
      config: config,
      destination: nil
    )

    #expect(task.shouldDebug == false)
  }

  // MARK: - Debug resolution logic tests

  @Test("nil debugRequest follows global debug true")
  func nilFollowsGlobalTrue() {
    let debugRequest: Bool? = nil
    let globalDebug = true
    #expect((debugRequest ?? globalDebug) == true)
  }

  @Test("nil debugRequest follows global debug false")
  func nilFollowsGlobalFalse() {
    let debugRequest: Bool? = nil
    let globalDebug = false
    #expect((debugRequest ?? globalDebug) == false)
  }

  @Test("true debugRequest overrides global debug false")
  func trueOverridesGlobalFalse() {
    let debugRequest: Bool? = true
    let globalDebug = false
    #expect((debugRequest ?? globalDebug) == true)
  }

  @Test("false debugRequest overrides global debug true")
  func falseOverridesGlobalTrue() {
    let debugRequest: Bool? = false
    let globalDebug = true
    #expect((debugRequest ?? globalDebug) == false)
  }

  // MARK: - Builder tests

  @Test("debug() builder sets true")
  func debugBuilderSetsTrue() {
    let endpoint: Endpoint<Data> = Endpoint<Data>(path: "users").debug()
    #expect(endpoint.debugRequest == true)
  }

  @Test("debug(false) builder sets false")
  func debugBuilderSetsFalse() {
    let endpoint: Endpoint<Data> = Endpoint<Data>(path: "users").debug(false)
    #expect(endpoint.debugRequest == false)
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
