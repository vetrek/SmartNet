# Testing Patterns

**Analysis Date:** 2026-01-09

## Test Framework

**Runner:**
- Swift Testing framework (Apple's modern testing framework)
- Uses `@Suite` and `@Test` attributes
- Config: Integrated with SPM test targets

**Assertion Library:**
- Swift Testing built-in macros
- `#expect()` for assertions
- `#require()` for unwrapping optionals
- `Issue.record()` for recording failures

**Run Commands:**
```bash
swift test                              # Run all tests
swift test --filter TestSuiteName       # Run specific suite
swift test --filter "test method name"  # Run specific test
```

## Test File Organization

**Location:**
- `Tests/UnitTests/` - Fast, isolated tests
- `Tests/IntegrationTests/` - Full request cycle with mocks

**Naming:**
- `FeatureTests.swift` for all test files
- No distinction in filename between unit/integration

**Structure:**
```
Tests/
├── UnitTests/
│   ├── RetryPolicyTests.swift         # Retry behavior
│   ├── EndpointRequestTests.swift     # URL building
│   ├── HTTPBodyTests.swift            # Body encoding
│   ├── HTTPPayloadTests.swift         # Payload construction
│   ├── ThreadSafetyTests.swift        # Thread safety
│   ├── LifecycleTests.swift           # Client lifecycle
│   ├── MultipartFormDataTests.swift   # Multipart forms
│   ├── EndpointBuilderTests.swift     # Builder pattern
│   ├── DownloadEndpointTests.swift    # Download endpoints
│   ├── DebugRequestTests.swift        # CURL debug output
│   └── MockApiClient.swift            # Test utilities
└── IntegrationTests/
    ├── AsyncRequestTests.swift        # async/await tests
    ├── ClosureRequestTests.swift      # Callback tests
    ├── CombineRequestTests.swift      # Combine tests
    ├── ErrorHandlingTests.swift       # Error scenarios
    ├── ApiClientMiddlewareTests.swift # Middleware pipeline
    ├── FileOperationTests.swift       # Upload/download
    ├── RequestConfigurationTests.swift# Config merging
    └── TestHelpers.swift              # Shared utilities
```

## Test Structure

**Suite Organization:**
```swift
import Testing
import Foundation
@testable import SmartNet

@Suite("Feature Name Tests")
struct FeatureTests {

  @Test("Description of test case")
  func testMethodName() async throws {
    // arrange
    let input = createTestInput()

    // act
    let result = functionUnderTest(input)

    // assert
    #expect(result == expectedOutput)
  }

  @Test("Error case handling")
  func errorCase() async throws {
    // test error scenarios
  }
}
```

**Patterns:**
- Use `@Suite("Name")` for grouping related tests
- Use `@Test("Description")` for individual tests
- Use `defer` blocks for cleanup
- Arrange-Act-Assert structure
- Async tests use `async throws`

## Mocking

**Framework:**
- Custom `MockURLProtocol` in `Tests/IntegrationTests/TestHelpers.swift`
- Thread-safe handler registration

**Patterns:**
```swift
import Testing
import Foundation
@testable import SmartNet

// Create mock client
let (client, _) = createMockClient()
defer { client.destroy(); MockURLProtocol.removeHandler(for: "/path") }

// Register mock handler
MockURLProtocol.setHandler(for: "/path") { request in
  let response = HTTPURLResponse(
    url: request.url!,
    statusCode: 200,
    httpVersion: nil,
    headerFields: ["Content-Type": "application/json"]
  )!
  let data = try! JSONEncoder().encode(expectedResult)
  return (response, data)
}

// Execute request
let response = try await client.request(with: endpoint)
```

**What to Mock:**
- URLSession via MockURLProtocol
- HTTP responses (status codes, data)
- Network errors (timeout, connection lost)

**What NOT to Mock:**
- Internal business logic
- Type encoding/decoding
- Thread safety mechanisms

## Fixtures and Factories

**Test Data:**
```swift
// Factory function in TestHelpers.swift
func createMockClient() -> (ApiClient, NetworkConfiguration) {
  let config = NetworkConfiguration(baseURL: URL(string: "https://test.com")!)
  let sessionConfig = URLSessionConfiguration.ephemeral
  sessionConfig.protocolClasses = [MockURLProtocol.self]
  let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)
  return (client, config)
}

// Test model
struct TestUser: Codable, Equatable, Sendable {
  let id: Int
  let name: String
  let email: String
}
```

**Location:**
- Factory functions: `Tests/IntegrationTests/TestHelpers.swift`
- Test models: Inline in test files or TestHelpers

## Coverage

**Requirements:**
- No enforced coverage target
- Focus on critical paths

**Configuration:**
- Standard Swift Testing coverage via Xcode
- No explicit coverage configuration

**Key Coverage Areas:**
- All three paradigms (async/await, Combine, closure)
- Error handling scenarios
- Retry policy behavior
- Middleware pipeline
- Thread safety

## Test Types

**Unit Tests:**
- Scope: Test single function/type in isolation
- Location: `Tests/UnitTests/`
- Mocking: Minimal, test pure logic
- Speed: Very fast (<100ms per test)
- Examples:
  - `RetryPolicyTests.swift` - Retry strategy calculations
  - `HTTPBodyTests.swift` - Body encoding
  - `ThreadSafetyTests.swift` - Concurrent access

**Integration Tests:**
- Scope: Test multiple components together
- Location: `Tests/IntegrationTests/`
- Mocking: Mock URLSession via MockURLProtocol
- Speed: Fast (real networking mocked)
- Examples:
  - `AsyncRequestTests.swift` - Full async request cycle
  - `ErrorHandlingTests.swift` - Error propagation
  - `ApiClientMiddlewareTests.swift` - Middleware pipeline

**E2E Tests:**
- Not currently implemented
- Real network tests would hit actual APIs

## Common Patterns

**Async Testing:**
```swift
@Test("Async request succeeds")
func asyncSuccess() async throws {
  let (client, _) = createMockClient()
  defer { client.destroy() }

  MockURLProtocol.setHandler(for: "/test") { _ in
    // return mock response
  }

  let response: TestModel = try await client.request(with: endpoint)
  #expect(response.property == expectedValue)
}
```

**Error Testing:**
```swift
@Test("Request fails with parsing error")
func parsingError() async throws {
  // Setup mock to return invalid JSON

  let response: Response<TestModel> = try await client.request(with: endpoint)

  switch response.result {
  case .success:
    Issue.record("Expected failure but got success")
  case .failure(let error):
    if case .parsingFailed = error {
      // Expected
    } else {
      Issue.record("Unexpected error type: \(error)")
    }
  }
}
```

**Closure-to-Async Bridge:**
```swift
let response: Response<Data> = await withCheckedContinuation { continuation in
  client.request(with: endpoint) { response in
    continuation.resume(returning: response)
  }
}
```

**Combine Testing:**
```swift
@Test("Combine publisher emits value")
func combineSuccess() async throws {
  let holder = CancellableHolder()

  let expectation = await withCheckedContinuation { continuation in
    let cancellable = client.request(with: endpoint)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          continuation.resume(returning: value)
        }
      )
    Task { await holder.store(cancellable) }
  }

  #expect(expectation == expectedValue)
}
```

**Snapshot Testing:**
- Not used in this codebase
- Prefer explicit assertions

---

*Testing analysis: 2026-01-09*
*Update when test patterns change*
