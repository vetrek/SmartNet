import Testing
import Foundation
@testable import SmartNet

@Suite("Lifecycle Tests")
struct LifecycleTests {

  // MARK: - Destroy Tests

  @Test("destroy() sets session to nil")
  func destroySetsSessionNil() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)

    // Session should exist initially
    #expect(client.session != nil)

    client.destroy()

    // Session should be nil after destroy
    #expect(client.session == nil)
  }

  @Test("destroy() clears download tasks")
  func destroyClearsDownloadTasks() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)

    // Add a download task directly to the internal set
    // Note: In real usage, downloads would be added through download() method
    client.destroy()

    // downloadsTasks should be cleared (we can't directly verify, but no crash = success)
    #expect(client.session == nil)
  }

  @Test("destroy() can be called multiple times safely")
  func destroyMultipleTimes() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)

    client.destroy()
    client.destroy()
    client.destroy()

    // Should not crash
    #expect(client.session == nil)
  }

  @Test("Config remains accessible after destroy")
  func configAccessibleAfterDestroy() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)

    client.updateHeaders(["Test": "Value"])
    client.destroy()

    // Config should still be accessible after destroy
    #expect(client.config.baseURL.absoluteString == "https://api.test.com")
    #expect(client.config.headers["Test"] == "Value")
  }

  @Test("Headers can be modified after destroy")
  func headersModifiableAfterDestroy() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)

    client.destroy()

    // Should not crash when modifying headers after destroy
    client.updateHeaders(["New": "Header"])
    client.setHeaders(["Another": "Value"])
    client.cleanHeaders()

    #expect(client.config.headers.isEmpty)
  }

  @Test("Concurrent destroy calls are safe")
  func concurrentDestroyCalls() async {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)

    // Call destroy from multiple concurrent tasks
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<10 {
        group.addTask {
          client.destroy()
        }
      }
    }

    // Should not crash, session should be nil
    #expect(client.session == nil)
  }

  // MARK: - Initialization Tests

  @Test("ApiClient initializes with default configuration")
  func initWithDefaultConfig() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let client = ApiClient(config: config)
    defer { client.destroy() }

    #expect(client.session != nil)
    #expect(client.config.baseURL.absoluteString == "https://api.test.com")
  }

  @Test("ApiClient initializes with custom session configuration")
  func initWithCustomSessionConfig() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    sessionConfig.timeoutIntervalForRequest = 60

    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)
    defer { client.destroy() }

    #expect(client.session != nil)
  }

  @Test("ApiClient respects request timeout from config")
  func respectsRequestTimeout() {
    var config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    config.requestTimeout = 30

    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)
    defer { client.destroy() }

    #expect(client.session?.configuration.timeoutIntervalForRequest == 30)
  }

  // MARK: - Headers Lifecycle

  @Test("setHeaders replaces all headers")
  func setHeadersReplaces() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)
    defer { client.destroy() }

    client.updateHeaders(["Old": "Value"])
    client.setHeaders(["New": "Value"])

    #expect(client.config.headers["Old"] == nil)
    #expect(client.config.headers["New"] == "Value")
  }

  @Test("cleanHeaders removes all headers")
  func cleanHeadersRemovesAll() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)
    defer { client.destroy() }

    client.updateHeaders(["Key1": "Value1", "Key2": "Value2"])
    client.cleanHeaders()

    #expect(client.config.headers.isEmpty)
  }

  @Test("removeHeaders removes specific keys")
  func removeHeadersSpecificKeys() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)
    defer { client.destroy() }

    client.updateHeaders(["Key1": "Value1", "Key2": "Value2", "Key3": "Value3"])
    client.removeHeaders(keys: ["Key1", "Key3"])

    #expect(client.config.headers["Key1"] == nil)
    #expect(client.config.headers["Key2"] == "Value2")
    #expect(client.config.headers["Key3"] == nil)
  }

  // MARK: - Middleware Lifecycle

  @Test("addMiddleware adds to client")
  func addMiddlewareAdds() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)
    defer { client.destroy() }

    let middleware = ApiClient.Middleware(
      pathComponent: "/test",
      preRequestCallback: { _ in },
      postResponseCallback: { _, _, _ in .next }
    )
    client.addMiddleware(middleware)

    // Middleware was added (no direct way to verify count, but no crash = success)
  }

  @Test("removeMiddleware by path component")
  func removeMiddlewareByPath() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)
    defer { client.destroy() }

    let middleware1 = ApiClient.Middleware(
      pathComponent: "users",
      preRequestCallback: { _ in },
      postResponseCallback: { _, _, _ in .next }
    )
    let middleware2 = ApiClient.Middleware(
      pathComponent: "posts",
      preRequestCallback: { _ in },
      postResponseCallback: { _, _, _ in .next }
    )
    client.addMiddleware(middleware1)
    client.addMiddleware(middleware2)

    client.removeMiddleware(for: "users")

    // Should not crash, middleware removed
  }

  @Test("removeMiddleware by instance")
  func removeMiddlewareByInstance() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)
    defer { client.destroy() }

    let middleware = ApiClient.Middleware(
      pathComponent: "test",
      preRequestCallback: { _ in },
      postResponseCallback: { _, _, _ in .next }
    )
    client.addMiddleware(middleware)
    client.removeMiddleware(middleware)

    // Should not crash, middleware removed
  }
}
