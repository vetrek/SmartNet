import Foundation
import Combine
import Testing
@testable import SmartNet

// MARK: - Test Models

struct TestUser: Codable, Equatable, Sendable {
  let id: Int
  let name: String
  let email: String
}

// MARK: - Mock Client Factory

func createMockClient() -> (ApiClient, NetworkConfiguration) {
  let sessionConfig = URLSessionConfiguration.ephemeral
  sessionConfig.protocolClasses = [MockURLProtocol.self]

  let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
  // Pass nil for delegateQueue to use a serial operation queue instead of main queue
  // This is required for Swift Testing which doesn't have a main run loop
  let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)

  return (client, config)
}

// MARK: - Cancellable Holder (for Combine tests)

actor CancellableHolder {
  private var cancellable: AnyCancellable?

  func store(_ cancellable: AnyCancellable) {
    self.cancellable = cancellable
  }
}

// MARK: - Mock URL Protocol (Thread-Safe for Parallel Tests)

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
  typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

  private static let lock = NSLock()
  private static var handlers: [String: Handler] = [:]

  /// Register a handler for a specific path pattern
  /// - Parameters:
  ///   - pattern: The URL path to match (e.g., "/users/1" or "users")
  ///   - handler: The handler to invoke for matching requests
  static func setHandler(for pattern: String, handler: @escaping Handler) {
    lock.lock()
    defer { lock.unlock() }
    handlers[pattern] = handler
  }

  /// Remove handler for a specific pattern
  static func removeHandler(for pattern: String) {
    lock.lock()
    defer { lock.unlock() }
    handlers.removeValue(forKey: pattern)
  }

  /// Clear all handlers
  static func reset() {
    lock.lock()
    defer { lock.unlock() }
    handlers.removeAll()
  }

  private static func findHandler(for request: URLRequest) -> Handler? {
    lock.lock()
    defer { lock.unlock() }

    guard let url = request.url else { return nil }
    let path = url.path

    // Try exact match first
    if let handler = handlers[path] {
      return handler
    }

    // Try matching without leading slash
    let pathWithoutSlash = path.hasPrefix("/") ? String(path.dropFirst()) : path
    if let handler = handlers[pathWithoutSlash] {
      return handler
    }

    // Try matching path components
    for (pattern, handler) in handlers {
      if path.contains(pattern) || pathWithoutSlash.contains(pattern) {
        return handler
      }
    }

    return nil
  }

  override class func canInit(with request: URLRequest) -> Bool {
    return true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    guard let handler = MockURLProtocol.findHandler(for: request) else {
      let error = NSError(
        domain: "MockURLProtocol",
        code: 0,
        userInfo: [NSLocalizedDescriptionKey: "No handler set for path: \(request.url?.path ?? "unknown")"]
      )
      client?.urlProtocol(self, didFailWithError: error)
      return
    }

    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {
    // Handle cancellation
  }
}

// MARK: - InputStream Extension

extension InputStream {
  func readAllData() -> Data {
    open()
    defer { close() }

    var data = Data()
    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while hasBytesAvailable {
      let bytesRead = read(buffer, maxLength: bufferSize)
      if bytesRead > 0 {
        data.append(buffer, count: bytesRead)
      }
    }

    return data
  }
}

// MARK: - Result Extension for Testing

extension SmartNet.Result {
  var isSuccess: Bool {
    switch self {
    case .success: return true
    case .failure: return false
    }
  }
}
