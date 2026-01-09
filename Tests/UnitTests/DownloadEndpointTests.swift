import Testing
import Foundation
@testable import SmartNet

@Suite("Download Endpoint Tests")
struct DownloadEndpointTests {

  // MARK: - URL Construction Tests

  @Test("DownloadEndpoint builds correct URL")
  func buildsCorrectURL() throws {
    let endpoint = DownloadEndpoint(path: "files/document.pdf")
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)

    let url = try endpoint.url(with: config)

    #expect(url.absoluteString == "https://api.test.com/files/document.pdf")
  }

  @Test("DownloadEndpoint with full path ignores base URL path")
  func fullPathIgnoresBasePath() throws {
    let endpoint = DownloadEndpoint(
      path: "https://cdn.example.com/files/image.png",
      isFullPath: true
    )
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com/v1")!)

    let url = try endpoint.url(with: config)

    #expect(url.absoluteString == "https://cdn.example.com/files/image.png")
  }

  @Test("DownloadEndpoint with query parameters")
  func withQueryParameters() throws {
    let endpoint = DownloadEndpoint(
      path: "files/download",
      queryParameters: QueryParameters(parameters: ["token": "abc123", "format": "pdf"])
    )
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)

    let request = try endpoint.urlRequest(with: config)

    let urlString = request.url!.absoluteString
    #expect(urlString.contains("token=abc123"))
    #expect(urlString.contains("format=pdf"))
  }

  // MARK: - Headers Tests

  @Test("DownloadEndpoint merges headers with config")
  func mergesHeaders() throws {
    let endpoint = DownloadEndpoint(
      path: "files/download",
      headers: ["Authorization": "Bearer token"]
    )
    let config = NetworkConfiguration(
      baseURL: URL(string: "https://api.test.com")!,
      headers: ["X-API-Key": "key123"]
    )

    let request = try endpoint.urlRequest(with: config)

    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    #expect(request.value(forHTTPHeaderField: "X-API-Key") == "key123")
  }

  @Test("DownloadEndpoint useEndpointHeaderOnly skips config headers")
  func useEndpointHeaderOnly() throws {
    let endpoint = DownloadEndpoint(
      path: "files/download",
      headers: ["Authorization": "Bearer token"],
      useEndpointHeaderOnly: true
    )
    let config = NetworkConfiguration(
      baseURL: URL(string: "https://api.test.com")!,
      headers: ["X-API-Key": "key123"]
    )

    let request = try endpoint.urlRequest(with: config)

    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    #expect(request.value(forHTTPHeaderField: "X-API-Key") == nil)
  }

  // MARK: - HTTP Method Tests

  @Test("DownloadEndpoint defaults to GET method")
  func defaultsToGet() throws {
    let endpoint = DownloadEndpoint(path: "files/download")
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)

    let request = try endpoint.urlRequest(with: config)

    #expect(request.httpMethod == "GET")
  }

  @Test("DownloadEndpoint can use custom method")
  func customMethod() throws {
    let endpoint = DownloadEndpoint(path: "files/download", method: .post)
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)

    let request = try endpoint.urlRequest(with: config)

    #expect(request.httpMethod == "POST")
  }

  // MARK: - Middleware Tests

  @Test("DownloadEndpoint allows middlewares by default")
  func allowsMiddlewaresByDefault() {
    let endpoint = DownloadEndpoint(path: "files/download")
    #expect(endpoint.allowMiddlewares == true)
  }

  @Test("DownloadEndpoint can disable middlewares")
  func canDisableMiddlewares() {
    let endpoint = DownloadEndpoint(path: "files/download", allowMiddlewares: false)
    #expect(endpoint.allowMiddlewares == false)
  }

  // MARK: - Debug Tests

  @Test("DownloadEndpoint debugRequest defaults to false")
  func debugRequestDefaultsFalse() {
    let endpoint = DownloadEndpoint(path: "files/download")
    #expect(endpoint.debugRequest == false)
  }

  @Test("DownloadEndpoint debugRequest can be enabled")
  func debugRequestCanBeEnabled() {
    let endpoint = DownloadEndpoint(path: "files/download", debugRequest: true)
    #expect(endpoint.debugRequest == true)
  }

  // MARK: - DownloadTask.DownloadFileDestination Tests

  @Test("DownloadFileDestination stores URL and replace flag")
  func downloadFileDestination() {
    let url = URL(fileURLWithPath: "/tmp/downloads/file.pdf")
    let destination = DownloadTask.DownloadFileDestination(url: url, removePreviousFile: true)

    #expect(destination.url == url)
    #expect(destination.removePreviousFile == true)
  }

  @Test("DownloadFileDestination with removePreviousFile false")
  func downloadFileDestinationNoReplace() {
    let url = URL(fileURLWithPath: "/tmp/downloads/file.pdf")
    let destination = DownloadTask.DownloadFileDestination(url: url, removePreviousFile: false)

    #expect(destination.removePreviousFile == false)
  }

  // MARK: - DownloadTask.DownloadState Tests

  @Test("DownloadState has all expected cases")
  func downloadStateHasAllCases() {
    let states: [DownloadTask.DownloadState] = [
      .waitingStart,
      .paused,
      .downloading,
      .completed,
      .cancelled,
      .error
    ]

    #expect(states.count == 6)
  }
}
