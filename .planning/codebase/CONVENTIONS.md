# Coding Conventions

**Analysis Date:** 2026-01-09

## Naming Patterns

**Files:**
- PascalCase for all files: `ApiClient.swift`, `NetworkError.swift`
- Extension pattern: `ClassName+Feature.swift` (e.g., `ApiClient+Async.swift`)
- Test files: `FeatureTests.swift`

**Functions:**
- camelCase for all functions: `urlRequest()`, `shouldRetry()`, `toDictionary()`
- No special prefix for async functions
- Builder methods return `Self` for chaining

**Variables:**
- camelCase for variables: `networkFailure`, `retryAfter`, `progressHUD`
- camelCase for constants: `maxRetries`, `baseDelay`
- No underscore prefix for private members

**Types:**
- PascalCase for classes/structs: `ApiClient`, `NetworkConfiguration`, `Endpoint<Value>`
- PascalCase for protocols without I prefix: `Requestable`, `RetryPolicy`, `NetworkConfigurable`
- PascalCase for enums: `HTTPMethod`, `NetworkError`, `BodyEncoding`
- camelCase for enum cases: `.parsingFailed`, `.connectionLost`, `.get`

## Code Style

**Formatting:**
- 2-space indentation throughout codebase
- No enforced line length (disabled in SwiftLint)
- Spaces around operators: `x + y`, `if condition {`

**SwiftLint:**
- Config: `.swiftlint.yml`
- Disabled rules:
  - `type_body_length` - Allows large types
  - `identifier_name` - Flexible naming
  - `large_tuple` - Allows larger tuples
  - `force_cast` - Uses force casting where needed
  - `line_length` - No limit
  - `file_length` - No limit
  - `nesting` - Allows nested types
- Run: `swiftlint` from project root

**Access Control:**
- Explicit `public` for library interfaces
- `public private(set)` for read-only public properties
- `internal` (default) for implementation details
- `private` for truly internal state

## Import Organization

**Order:**
1. System frameworks (Foundation, Combine)
2. No external packages (zero dependencies)

**Grouping:**
- Single import per line
- No blank lines between imports

## Error Handling

**Patterns:**
- All errors typed as `NetworkError` enum
- Throw from functions, catch at boundaries
- Use `Result<Value>` enum for async completion

**Error Types:**
- `NetworkError` for all network failures
- Cases cover: HTTP errors, parsing, timeout, connection, SSL, rate limiting

**Example from `Source/Utils/NetworkError.swift`:**
```swift
public enum NetworkError: Error, Sendable, Equatable {
  case error(statusCode: Int, data: Data?)
  case parsingFailed
  case timeout
  case connectionLost
  // ... more cases
}
```

## Logging

**Framework:**
- `SmartNetLogger` via Apple's os_log
- Location: `Source/Utils/Logger.swift`
- Levels: debug, info, warning, error, none

**Patterns:**
- Log at significant state changes
- Include context in log messages
- No console.log in committed code

**Usage:**
```swift
SmartNetLogger.shared.log("Message", level: .info)
```

## Comments

**When to Comment:**
- Explain why, not what
- Document public APIs with `///` docstrings
- Use `// MARK: -` for section organization

**DocString Format:**
```swift
/// Sends a request to the provided endpoint.
///
/// - Parameters:
///   - endpoint: The endpoint to send the request to.
///   - decoder: The JSON decoder to use.
/// - Returns: The decoded response.
/// - Throws: NetworkError if request fails.
```

**Section Markers:**
- `// MARK: - Section Name` for logical sections
- Examples from `Source/Core/ApiClient.swift`:
  - `// MARK: - Internal properties`
  - `// MARK: - Public Utility Methods`
  - `// MARK: - URLSessionDelegate`

**File Headers:**
- MIT license header on all files
- Copyright to Valerio69

## Function Design

**Size:**
- No strict limit (SwiftLint disabled)
- Prefer smaller functions when reasonable
- Complex functions may be 50+ lines

**Parameters:**
- Use default values where appropriate
- Use trailing closure syntax for completion handlers
- Use `@escaping` for stored closures

**Return Values:**
- Explicit return types on all functions
- Generic types for type-safe responses: `Endpoint<Value>`
- Optional returns for fallible operations

## Module Design

**Exports:**
- All public API in `Source/` directory
- Single target "SmartNet" in `Package.swift`
- No barrel files (SPM handles exports)

**Extensions:**
- Group related functionality: `ApiClient+Async.swift`
- Each paradigm in separate file
- Protocols in dedicated files

**Protocol Conformance:**
- Conform in extensions when adding functionality
- Main conformance in type definition

## Property Wrappers

**@ThreadSafe:**
- Location: `Source/Utils/ThreadSafe.swift`
- Use for mutable shared state
- Applied to: config, middlewares, task collections

**Example:**
```swift
@ThreadSafe
public private(set) var config: NetworkConfigurable
```

## Sendable Conformance

**Pattern:**
- Mark types as `Sendable` for Swift concurrency
- Use `@unchecked Sendable` when compiler can't verify

**Example:**
```swift
public enum NetworkError: Error, Sendable, Equatable {
```

---

*Convention analysis: 2026-01-09*
*Update when patterns change*
