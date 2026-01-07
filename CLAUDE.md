# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
swift build              # Build the library
swift test               # Run all tests
swift test --filter TestName  # Run a specific test
swiftlint                # Run linter (Source/ and Tests/)
```

## Architecture

SmartNet is a Swift HTTP networking library for iOS 13+ and macOS 10.15+ with no external dependencies. It supports three programming paradigms: Async/Await, Combine, and closures.

### Core Components

**ApiClient** (`Source/Core/ApiClient.swift`) - Main entry point. Manages URLSession, middleware registration, and request execution. Extensions in separate files handle each paradigm:
- `ApiClient+Async.swift` - async/await methods
- `ApiClient+Combine.swift` - Combine publishers
- `ApiClient+Closure.swift` - callback-based methods
- `ApiClient+Middleware.swift` - middleware pipeline
- `ApiClient+Upload.swift` / `ApiClient+Download.swift` - file operations
- `ApiClient+CURL.swift` - debug logging

**Endpoint<Value>** (`Source/Endpoint/Endpoint.swift`) - Generic, type-safe endpoint definition. Conforms to `Requestable` protocol which defines URL construction, headers, body encoding, and middleware configuration.

**NetworkConfiguration** (`Source/Core/NetworkConfiguration.swift`) - Holds baseURL, default headers, query parameters, timeouts, debug settings, and default retry policy.

### Request Flow

1. `Endpoint<T>` defines path, method, body, headers, query params, optional retry policy
2. ApiClient applies middleware pre-request callbacks
3. URLSession executes request
4. On failure, retry policy determines if/when to retry (with backoff delay)
5. Middleware post-response callbacks run (can return `.next` or `.retryRequest`)
6. Response decoded to type `T` and returned

### Middleware System

Middlewares target specific path components and execute in registration order:
- `pathComponent: "/"` - global middleware (all requests)
- `pathComponent: "user"` - matches paths containing "user"
- `preRequestCallback` - modify request before sending (throws to cancel)
- `postResponseCallback` - process response, can trigger retry

### Retry Policies

`RetryPolicy` protocol (`Source/Core/RetryPolicy.swift`) defines automatic retry behavior:

**Built-in Policies:**
- `ExponentialBackoffRetryPolicy` - Default. Delays: 1s, 2s, 4s, 8s... with optional jitter
- `LinearBackoffRetryPolicy` - Linear delays: 1s, 2s, 3s, 4s...
- `ImmediateRetryPolicy` - Retry immediately without delay
- `NoRetryPolicy` - Disable retries entirely

**RetryCondition** flags control which errors trigger retries:
- `.timeout`, `.connectionLost`, `.networkFailure`, `.serverError` (5xx), `.rateLimited` (429), `.dnsFailure`
- `.default` = [timeout, connectionLost, networkFailure, serverError]

**Configuration:**
- Set global default via `NetworkConfiguration.retryPolicy`
- Override per-endpoint via `Endpoint.retryPolicy`
- Rate-limited responses (429) respect server's `Retry-After` header

### Logging

`SmartNetLogger` (`Source/Utils/Logger.swift`) provides unified logging via `os_log`:
- Levels: `.debug`, `.info`, `.warning`, `.error`, `.none`
- Default: `.debug` in DEBUG builds, `.warning` in release
- Access via `SmartNetLogger.shared`

### Thread Safety

`@ThreadSafe` property wrapper (`Source/Utils/ThreadSafe.swift`) uses pthread_mutex for concurrent access. Applied to config and task collections in ApiClient.

### Key Protocols

- `Requestable` - base protocol for all endpoint types
- `RetryPolicy` - defines retry behavior (maxRetries, shouldRetry, delay)
- `MiddlewareProtocol` - middleware implementation contract
- `NetworkCancellable` - cancellation interface for requests

### Error Handling

`NetworkError` enum (`Source/Utils/NetworkError.swift`) covers all failure cases:
- HTTP errors (`.error(statusCode:data:)`)
- Parsing failures (`.parsingFailed`)
- Middleware errors (`.middleware(Error)`, `.middlewareMaxRetry`)
- Network conditions (`.timeout`, `.connectionLost`, `.networkFailure`, `.dnsLookupFailed`)
- Security (`.sslError(Error?)`)
- Rate limiting (`.rateLimited(retryAfter:)`)
- Cancellation (`.cancelled`)

## Testing

Tests use Swift Testing framework (`@Suite`, `@Test`, `#expect`). Two test targets:

**Unit Tests** (`Tests/UnitTests/`) - Fast, isolated tests:
- `RetryPolicyTests.swift` - retry policy behavior and conditions
- `EndpointRequestTests.swift` - request URL/header generation
- `HTTPBodyTests.swift` - body encoding (JSON, form URL encoded)
- `ThreadSafetyTests.swift` - concurrent access safety
- `LifecycleTests.swift` - ApiClient lifecycle and cleanup

**Integration Tests** (`Tests/IntegrationTests/`) - Full request cycle with MockURLProtocol:
- `ClosureRequestTests.swift`, `AsyncRequestTests.swift`, `CombineRequestTests.swift` - all paradigms
- `ErrorHandlingTests.swift` - error case coverage
- `ApiClientMiddlewareTests.swift` - middleware pipeline behavior
- `FileOperationTests.swift` - download/upload operations

## Code Conventions

- When modifying request handling, update all three paradigm files (Async, Combine, Closure) for consistency
- Use `@ThreadSafe` for any shared mutable state
- Throw `NetworkError` cases for failures
- Upload/download APIs use builder pattern with chainable methods

## Git Commits

- Do NOT append the Claude Code attribution or Co-Authored-By lines to commit messages
