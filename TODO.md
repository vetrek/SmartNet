# SmartNet Improvement Roadmap

A phased approach to making SmartNet a world-class Swift networking library.

---

## Git Workflow

Each phase should be developed on a dedicated branch:

```bash
# Start a new phase
git checkout master
git pull origin master
git checkout -b phase-X-description

# When phase is complete
git checkout master
git merge phase-X-description
git push origin master

# Start next phase
git checkout -b phase-Y-description
```

### Branch Naming Convention

| Phase | Branch Name |
|-------|-------------|
| Phase 1 | `phase-1-safety-fixes` |
| Phase 2 | `phase-2-test-foundation` |
| Phase 3 | `phase-3-error-handling` |
| Phase 4 | `phase-4-retry-policies` |
| Phase 5 | `phase-5-api-modernization` |
| Phase 6 | `phase-6-middleware` |
| Phase 7 | `phase-7-caching` |
| Phase 8 | `phase-8-security` |
| Phase 9 | `phase-9-reachability` |
| Phase 10 | `phase-10-advanced-features` |
| Phase 11 | `phase-11-documentation` |
| Phase 12 | `phase-12-platforms` |

---

## Phase 1: Critical Safety Fixes
*Estimated effort: 1-2 days*

### Force Unwrap Crashes
- [x] Fix `response.error!` force unwrap in `Source/Core/ApiClient+Async.swift:80`
- [x] Fix `responseError!` force unwrap in `Source/Core/ApiClient+Upload.swift:248`
- [x] Fix `responseError!` force unwrap in `Source/Core/ApiClient+Closure.swift:157`

### Silent Failures
- [x] Add completion callback for early returns in `Source/Core/ApiClient+Download.swift:141-149`
- [x] Ensure all error paths call completion handlers

### Thread Safety
- [x] Make `middlewares` array thread-safe with `@ThreadSafe` in `Source/Core/ApiClient.swift:69`
- [x] Fix race condition in download limit check `Source/Core/ApiClient+Download.swift:282-287`

> Note: `session` property uses optional chaining throughout, making explicit thread-safety unnecessary.

### Bugs
- [x] Fix `maxConcurrentUploads = 60_000_000` to reasonable value (e.g., 6) in `Source/Core/ApiClient.swift:64`
- [x] Replace `fatalError()` with `throw` in `Source/Endpoint/QueryParameters.swift:37-38`

---

## Phase 2: Test Foundation
*Estimated effort: 1-2 weeks*

### Core Request Tests
- [x] Test closure-based `request()` success path
- [x] Test closure-based `request()` error paths
- [x] Test async/await `request()` success path
- [x] Test async/await `request()` error paths
- [x] Test Combine publisher success path
- [x] Test Combine publisher error paths

### Error Scenario Tests
- [x] Test HTTP 4xx error handling
- [x] Test HTTP 5xx error handling
- [x] Test network timeout behavior
- [x] Test network unreachable behavior
- [x] Test request cancellation
- [x] Test empty response handling
- [x] Test JSON parsing failures

### File Operation Tests
- [x] Test download endpoint construction (DownloadEndpointTests)
- [x] Test download state management (FileOperationTests)
- [x] Test download pause/resume state (FileOperationTests)
- [x] Test download cancellation (FileOperationTests)
- [x] Test concurrent download limit (FileOperationTests)
- [x] Test upload endpoint construction (MultipartFormDataTests)
- [x] Test upload multipart request creation (FileOperationTests)
- [x] Test multipart form data encoding

### Thread Safety Tests
- [x] Test concurrent access to `@ThreadSafe` properties
- [x] Test middleware modification during iteration
- [x] Test session access during destruction (LifecycleTests)

### Memory Tests
- [ ] Test for retain cycles in closures (complex - requires memory profiling)
- [x] Test `destroy()` properly cleans up resources (LifecycleTests)
- [ ] Test cancellation releases references (complex - requires memory profiling)

---

## Phase 3: Error Handling Improvements
*Estimated effort: 3-5 days*

### Better Error Resolution
- [ ] Add `.timeout` case to `NetworkError`
- [ ] Add `.dnsLookupFailed` case to `NetworkError`
- [ ] Add `.sslError` case to `NetworkError`
- [ ] Add `.connectionLost` case to `NetworkError`
- [ ] Add `.rateLimited(retryAfter:)` case for 429 responses
- [ ] Update `resolve(error:)` in `Source/Core/ApiClient.swift:194-212` to use specific cases
- [ ] Add request context (URL, method) to error cases

### Error Logging
- [ ] Replace `print()` statements with proper logging protocol
- [ ] Add configurable log levels (debug, info, warning, error)
- [ ] Add structured logging support

---

## Phase 4: Retry Policies
*Estimated effort: 1 week*

### Retry Infrastructure
- [ ] Create `RetryPolicy` protocol
- [ ] Implement `ExponentialBackoffRetryPolicy`
- [ ] Implement `LinearBackoffRetryPolicy`
- [ ] Implement `ImmediateRetryPolicy`
- [ ] Add jitter support to backoff calculations

### Retry Integration
- [ ] Add `retryPolicy` property to `Requestable` protocol
- [ ] Add default retry policy to `NetworkConfiguration`
- [ ] Remove hardcoded `retryCount < 2` from `ApiClient+Closure.swift:274`
- [ ] Add retry count to error context

### Retry Conditions
- [ ] Retry on timeout errors
- [ ] Retry on connection lost
- [ ] Retry on 5xx server errors
- [ ] Configurable retry conditions per policy

---

## Phase 5: API Modernization
*Estimated effort: 1-2 weeks*

### Typed Throws
- [ ] Change `request()` to `throws(NetworkError)`
- [ ] Change middleware callbacks to typed throws
- [ ] Update all throwing functions to use typed throws
- [ ] Add migration guide for users

### HTTPPayload Enum
- [ ] Create `HTTPPayload` enum with cases: `.json`, `.formUrlEncoded`, `.multipart`, `.raw`
- [ ] Replace separate `body` and `form` properties in `Requestable`
- [ ] Update `Endpoint` to use new enum
- [ ] Update request building logic

### Result Builder for MultipartFormData
- [ ] Create `@MultipartBuilder` result builder
- [ ] Add DSL-style field addition
- [ ] Update `MultipartFormEndpoint` to use builder
- [ ] Add documentation with examples

### Endpoint Builder Pattern
- [ ] Create `EndpointBuilder<T>` type
- [ ] Add static factory methods (`.get()`, `.post()`, etc.)
- [ ] Add chainable methods (`.headers()`, `.body()`, `.query()`)
- [ ] Maintain backward compatibility with existing initializer

---

## Phase 6: Middleware Improvements
*Estimated effort: 1 week*

### Path Matching
- [ ] Add exact path matching option
- [ ] Add regex path matching
- [ ] Add glob pattern matching (e.g., `/users/*`)
- [ ] Add wildcard support

### Middleware Control
- [ ] Add priority/ordering system
- [ ] Add ability to halt request pipeline
- [ ] Add ability to modify request in `postResponse`
- [ ] Add middleware-specific configuration per endpoint

### Middleware Result
- [ ] Add `.skip` result to skip remaining middlewares
- [ ] Add `.retryWithRequest(URLRequest)` for modified retries
- [ ] Add configurable max retry count per middleware

---

## Phase 7: Response Caching
*Estimated effort: 1-2 weeks*

### Cache Infrastructure
- [ ] Create `ResponseCache` protocol
- [ ] Implement `InMemoryCache` with LRU eviction
- [ ] Implement `DiskCache` for persistent storage
- [ ] Add cache key generation from requests

### HTTP Caching
- [ ] Support `Cache-Control` header directives
- [ ] Support `ETag` / `If-None-Match`
- [ ] Support `Last-Modified` / `If-Modified-Since`
- [ ] Support `Expires` header
- [ ] Handle `304 Not Modified` responses

### Cache Configuration
- [ ] Add cache policy to `NetworkConfiguration`
- [ ] Add per-endpoint cache override
- [ ] Add cache invalidation API
- [ ] Add cache size limits

---

## Phase 8: Security Features
*Estimated effort: 1-2 weeks*

### Certificate Pinning
- [ ] Create `ServerTrustEvaluating` protocol
- [ ] Implement `PublicKeyPinningEvaluator`
- [ ] Implement `CertificatePinningEvaluator`
- [ ] Add pinning configuration to `NetworkConfiguration`
- [ ] Add per-host pinning support
- [ ] Add pin expiration warnings

### SSL/TLS
- [ ] Add minimum TLS version configuration
- [ ] Add cipher suite configuration
- [ ] Add SSL error detailed reporting

---

## Phase 9: Network Reachability
*Estimated effort: 3-5 days*

### Reachability Monitor
- [ ] Create `NetworkReachabilityManager`
- [ ] Detect WiFi vs Cellular
- [ ] Detect connection transitions
- [ ] Add reachability change callbacks

### Integration
- [ ] Pause requests when unreachable (optional)
- [ ] Auto-retry when connectivity restored
- [ ] Add reachability to request context

---

## Phase 10: Advanced Features
*Estimated effort: 2-4 weeks*

### Request Deduplication
- [ ] Track in-flight requests by key
- [ ] Coalesce identical concurrent requests
- [ ] Share responses across deduplicated requests

### Metrics & Tracing
- [ ] Create `EventMonitor` protocol
- [ ] Track request/response timing
- [ ] Track bytes sent/received
- [ ] Add distributed tracing hooks (trace ID, span ID)

### Streaming
- [ ] Support chunked transfer encoding
- [ ] Support server-sent events (SSE)
- [ ] Add streaming response handler

### WebSocket (Optional)
- [ ] Add WebSocket connection support
- [ ] Add message send/receive
- [ ] Add auto-reconnect logic

---

## Phase 11: Documentation
*Estimated effort: 1 week*

### API Documentation
- [ ] Document all public types with doc comments
- [ ] Document all public methods with parameters and returns
- [ ] Add code examples in doc comments
- [ ] Generate DocC documentation

### Guides
- [ ] Write architecture overview guide
- [ ] Write error handling guide
- [ ] Write authentication patterns guide (token refresh)
- [ ] Write testing/mocking guide
- [ ] Write migration guide from Alamofire

### Examples
- [ ] Create example project with common patterns
- [ ] Add README examples for all features
- [ ] Add troubleshooting FAQ

---

## Phase 12: Platform Expansion (Optional)
*Estimated effort: Variable*

### Additional Platforms
- [ ] Add tvOS support
- [ ] Add watchOS support
- [ ] Add visionOS support
- [ ] Test and document Linux support

---

## Progress Summary

| Phase | Branch | Status | Completion |
|-------|--------|--------|------------|
| Phase 1: Safety Fixes | `phase-1-safety-fixes` | Complete | 100% |
| Phase 2: Test Foundation | `phase-2-test-foundation` | In Progress | 93% |
| Phase 3: Error Handling | `phase-3-error-handling` | Not Started | 0% |
| Phase 4: Retry Policies | `phase-4-retry-policies` | Not Started | 0% |
| Phase 5: API Modernization | `phase-5-api-modernization` | Not Started | 0% |
| Phase 6: Middleware | `phase-6-middleware` | Not Started | 0% |
| Phase 7: Caching | `phase-7-caching` | Not Started | 0% |
| Phase 8: Security | `phase-8-security` | Not Started | 0% |
| Phase 9: Reachability | `phase-9-reachability` | Not Started | 0% |
| Phase 10: Advanced | `phase-10-advanced-features` | Not Started | 0% |
| Phase 11: Documentation | `phase-11-documentation` | Not Started | 0% |
| Phase 12: Platforms | `phase-12-platforms` | Not Started | 0% |

---

## Quick Reference: File Locations

| Component | Path |
|-----------|------|
| ApiClient | `Source/Core/ApiClient.swift` |
| ApiClientProtocol | `Source/Core/ApiClientProtocol.swift` |
| DownloadClientProtocol | `Source/Core/DownloadClientProtocol.swift` |
| UploadClientProtocol | `Source/Core/UploadClientProtocol.swift` |
| Async Extension | `Source/Core/ApiClient+Async.swift` |
| Closure Extension | `Source/Core/ApiClient+Closure.swift` |
| Combine Extension | `Source/Core/ApiClient+Combine.swift` |
| Middleware | `Source/Core/ApiClient+Middleware.swift` |
| Download | `Source/Core/ApiClient+Download.swift` |
| Upload | `Source/Core/ApiClient+Upload.swift` |
| Endpoint | `Source/Endpoint/Endpoint.swift` |
| Requestable | `Source/Endpoint/Requestable.swift` |
| HTTPBody | `Source/Endpoint/HTTPBody.swift` |
| NetworkError | `Source/Utils/NetworkError.swift` |
| ThreadSafe | `Source/Utils/ThreadSafe.swift` |
| Integration Tests | `Tests/IntegrationTests/` |
| Unit Tests | `Tests/UnitTests/` |
| MockApiClient | `Tests/UnitTests/MockApiClient.swift` |
| TestHelpers | `Tests/IntegrationTests/TestHelpers.swift` |
