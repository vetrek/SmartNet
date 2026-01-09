# Architecture

**Analysis Date:** 2026-01-09

## Pattern Overview

**Overall:** Protocol-Oriented, Type-Safe HTTP Networking Library

**Key Characteristics:**
- Layered architecture with strong abstraction boundaries
- Multiple programming paradigm support (async/await, Combine, closures)
- Generic type-safe endpoints with `Endpoint<Value>`
- Extension-based feature partitioning
- Middleware pattern for cross-cutting concerns
- Property wrapper pattern for thread-safety

## Layers

**API Layer (Entry Points):**
- Purpose: Public interface consumers interact with
- Contains: Main client class and protocol
- Files: `Source/Core/ApiClient.swift`, `Source/Core/ApiClientProtocol.swift`
- Used by: Consumer applications

**Core Orchestration Layer:**
- Purpose: Request/response coordination per paradigm
- Contains: Async, Combine, and Closure implementations
- Files: `Source/Core/ApiClient+Async.swift`, `Source/Core/ApiClient+Combine.swift`, `Source/Core/ApiClient+Closure.swift`
- Depends on: Configuration layer, URLSession
- Used by: API layer methods

**File Operations Layer:**
- Purpose: Download and upload handling
- Contains: Progress tracking, task management
- Files: `Source/Core/ApiClient+Download.swift`, `Source/Core/ApiClient+Upload.swift`
- Depends on: Core layer, URLSession delegates
- Used by: API layer methods

**Configuration & Policies Layer:**
- Purpose: Global network behavior settings
- Contains: NetworkConfiguration, RetryPolicy implementations
- Files: `Source/Core/NetworkConfiguration.swift`, `Source/Core/RetryPolicy.swift`
- Used by: All request execution

**Middleware Layer:**
- Purpose: Request/response interception
- Contains: Middleware protocol and struct
- Files: `Source/Core/ApiClient+Middleware.swift`
- Depends on: Endpoint definitions
- Used by: Request execution pipeline

**Endpoint Definition Layer:**
- Purpose: Type-safe request specification
- Contains: Endpoint, Requestable protocol, body encoding
- Files: `Source/Endpoint/Endpoint.swift`, `Source/Endpoint/Protocol/Requestable.swift`, `Source/Endpoint/HTTPBody.swift`
- Used by: Consumers to define requests

**Response Layer:**
- Purpose: Response modeling
- Contains: Response wrapper, Result enum
- Files: `Source/Response/Response.swift`, `Source/Response/Result.swift`
- Used by: All request completions

**Utilities Layer:**
- Purpose: Cross-cutting concerns
- Contains: Error types, logging, thread safety
- Files: `Source/Utils/NetworkError.swift`, `Source/Utils/Logger.swift`, `Source/Utils/ThreadSafe.swift`
- Used by: All layers

## Data Flow

**HTTP Request Lifecycle:**

1. Consumer creates `Endpoint<T>` with path, method, headers, body
2. Consumer calls `ApiClient.request(with: endpoint)`
3. ApiClient creates `URLRequest` via `Requestable.urlRequest(config:)`
4. Global headers from `NetworkConfiguration` merged with endpoint headers
5. Middleware `preRequestCallback` runs (can modify request or throw to cancel)
6. URLSession executes request
7. Response received, status code validated
8. If error and `RetryPolicy.shouldRetry()` returns true:
   - Calculate delay via `RetryPolicy.delay()`
   - Wait for delay, increment retry count, return to step 6
9. Middleware `postResponseCallback` runs (can return `.next` or `.retryRequest`)
10. Response decoded to type `T` via JSONDecoder
11. `Response<T>` returned with result, request, response metadata

**State Management:**
- Stateless request handling (no persistent state between requests)
- `@ThreadSafe` wrapper protects config and task collections
- URLSession manages connection pooling

## Key Abstractions

**Requestable Protocol:**
- Purpose: Defines HTTP request structure
- Files: `Source/Endpoint/Protocol/Requestable.swift`
- Pattern: Protocol with default implementations
- Key methods: `urlRequest(with:)`, path, method, headers

**Endpoint<Value>:**
- Purpose: Type-safe endpoint with generic response type
- Files: `Source/Endpoint/Endpoint.swift`
- Pattern: Generic struct conforming to Requestable
- Features: Builder pattern for fluent configuration

**RetryPolicy Protocol:**
- Purpose: Defines retry behavior
- Files: `Source/Core/RetryPolicy.swift`
- Implementations: ExponentialBackoffRetryPolicy, LinearBackoffRetryPolicy, ImmediateRetryPolicy, NoRetryPolicy
- Key methods: `shouldRetry(attempt:error:)`, `delay(for:error:)`

**MiddlewareProtocol:**
- Purpose: Request/response interception
- Files: `Source/Core/ApiClient+Middleware.swift`
- Pattern: Path-component matching
- Callbacks: preRequestCallback, postResponseCallback

**@ThreadSafe<Value>:**
- Purpose: Thread-safe property access
- Files: `Source/Utils/ThreadSafe.swift`
- Pattern: Property wrapper with pthread_mutex
- Used for: config, middlewares, download/upload tasks

## Entry Points

**ApiClient:**
- Location: `Source/Core/ApiClient.swift`
- Triggers: Consumer instantiation with `NetworkConfiguration`
- Responsibilities: URLSession management, request execution, middleware pipeline

**Initialization:**
```swift
init(config: NetworkConfigurable)
init(config: NetworkConfigurable, sessionConfiguration: URLSessionConfiguration, delegateQueue: OperationQueue?)
```

**Request Methods (per paradigm):**
- `request(with:decoder:progressHUD:)` - async/await
- `request(with:decoder:queue:progressHUD:)` - Combine publisher
- `request(with:decoder:queue:progressHUD:completion:)` - closure callback

## Error Handling

**Strategy:** Throw `NetworkError`, catch at boundaries, support retry

**Patterns:**
- All errors mapped to `NetworkError` enum cases
- Retry policies evaluate error type via `RetryCondition`
- Middleware can trigger retries via `.retryRequest` response
- Consumers receive `Response<T>` with `Result<T>` for success/failure

**NetworkError Cases:** (from `Source/Utils/NetworkError.swift`)
- `.error(statusCode:data:)` - HTTP error responses
- `.parsingFailed` - JSON decoding failures
- `.timeout` - Request timeout
- `.connectionLost` - Network connection lost
- `.networkFailure` - General network error
- `.rateLimited(retryAfter:)` - 429 with Retry-After
- `.sslError(Error?)` - SSL/TLS failures
- `.cancelled` - Request cancelled

## Cross-Cutting Concerns

**Logging:**
- `SmartNetLogger` via os_log - `Source/Utils/Logger.swift`
- Configurable levels: debug, info, warning, error, none
- Default: debug in DEBUG builds, warning in release

**Thread Safety:**
- `@ThreadSafe` property wrapper
- pthread_mutex synchronization
- Applied to: config, middlewares, task collections

**Debug:**
- CURL logging - `Source/Core/ApiClient+CURL.swift`
- Enabled via `Endpoint.debugRequest` flag

---

*Architecture analysis: 2026-01-09*
*Update when major patterns change*
