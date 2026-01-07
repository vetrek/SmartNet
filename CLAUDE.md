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

**NetworkConfiguration** (`Source/Core/NetworkConfiguration.swift`) - Holds baseURL, default headers, query parameters, timeouts, and debug settings.

### Request Flow

1. `Endpoint<T>` defines path, method, body, headers, query params
2. ApiClient applies middleware pre-request callbacks
3. URLSession executes request
4. Middleware post-response callbacks run (can return `.next` or `.retryRequest`)
5. Response decoded to type `T` and returned

### Middleware System

Middlewares target specific path components and execute in registration order:
- `pathComponent: "/"` - global middleware (all requests)
- `pathComponent: "user"` - matches paths containing "user"
- `preRequestCallback` - modify request before sending (throws to cancel)
- `postResponseCallback` - process response, can trigger retry

### Thread Safety

`@ThreadSafe` property wrapper (`Source/Utils/ThreadSafe.swift`) uses pthread_mutex for concurrent access. Applied to config and task collections in ApiClient.

### Key Protocols

- `Requestable` - base protocol for all endpoint types
- `MiddlewareProtocol` - middleware implementation contract
- `NetworkCancellable` - cancellation interface for requests

### Error Handling

`NetworkError` enum (`Source/Utils/NetworkError.swift`) covers all failure cases: HTTP errors, parsing failures, middleware errors, cancellation, network failures.

## Testing

Tests use XCTest in `Tests/SmartNetTests/`. Pattern: setUp creates ApiClient, tearDown calls `client.destroy()` to prevent retain cycles.

Key test files:
- `ApiClientMiddlewareTests.swift` - middleware pipeline behavior
- `EndpointRequestTests.swift` - request URL/header generation
- `HTTPBodyTests.swift` - body encoding (JSON, form URL encoded)

## Code Conventions

- When modifying request handling, update all three paradigm files (Async, Combine, Closure) for consistency
- Use `@ThreadSafe` for any shared mutable state
- Throw `NetworkError` cases for failures
- Upload/download APIs use builder pattern with chainable methods

## Git Commits

- Do NOT append the Claude Code attribution or Co-Authored-By lines to commit messages
