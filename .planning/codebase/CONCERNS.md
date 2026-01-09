# Codebase Concerns

**Analysis Date:** 2026-01-09

## Tech Debt

**Generic NSError instead of NetworkError:**
- Issue: Uses generic NSError in upload error handling instead of typed NetworkError
- Files: `Source/Core/ApiClient+Upload.swift` (line ~88)
- Why: Quick error throw during form data validation
- Impact: Poor error semantics, hard to debug, inconsistent with rest of codebase
- Fix approach: Replace `throw NSError(domain: "1", code: 1)` with `throw NetworkError.invalidFormData` or appropriate case

**Silent error suppression in form building:**
- Issue: Multipart form data building can fail silently
- Files: `Source/Endpoint/MultipartFormEndpoint.swift` (line ~150)
- Why: `guard let data = string.data(using: .utf8) else { return }` discards failures
- Impact: Form building can silently skip fields without error
- Fix approach: Throw error or return Result type from addDataField

## Known Bugs

**None detected** - Tests pass, codebase is clean

## Security Considerations

**SSL Trust Handling:**
- Risk: Custom trusted domains bypass standard certificate validation
- Files: `Source/Core/ApiClient.swift` (URLAuthenticationChallenge handling)
- Current mitigation: Trusted domains must be explicitly configured via NetworkConfiguration
- Recommendations: Document security implications, consider certificate pinning option

**No Secret Management:**
- Risk: Library doesn't provide secure credential storage
- Files: N/A - This is consumer responsibility
- Current mitigation: Auth tokens are passed via headers, not stored
- Recommendations: Document that consumers should use Keychain for sensitive data

## Performance Bottlenecks

**None detected** - Standard URLSession performance

**Large File Line Counts:**
- Files exceeding 400 lines may impact readability:
  - `Source/Core/ApiClient+Closure.swift` (469 lines)
  - `Source/Core/ApiClient+Upload.swift` (467 lines)
  - `Source/Core/ApiClient+Download.swift` (429 lines)
- Impact: Maintenance burden, harder to navigate
- Improvement path: Consider extracting helper types for state management

## Fragile Areas

**Force Unwraps:**
- Files:
  - `Source/Endpoint/HTTPBody.swift` (line ~117) - `parameters[key]!`
  - `Source/Core/ApiClient+Upload.swift` (line ~203) - `error!`
- Why fragile: Force unwraps crash on nil
- Common failures: Would crash if assumptions are violated
- Safe modification: Replace with guard statements or optional chaining
- Test coverage: Protected paths are tested, but defensive coding would be better

**Retry Logic Complexity:**
- Files: `Source/Core/ApiClient+Closure.swift` (lines ~309-342)
- Why fragile: Complex state machine for retry scheduling
- Common failures: Edge cases in retry timing could behave unexpectedly
- Safe modification: Document retry flow, add more inline comments
- Test coverage: Good coverage in `RetryPolicyTests.swift`

## Scaling Limits

**Concurrent Download Limit:**
- Current capacity: Configurable, default varies
- Files: `Source/Core/ApiClient+Download.swift`
- Limit: Memory pressure with many large downloads
- Symptoms at limit: Memory warnings, potential OOM
- Scaling path: Downloads are queued, limit is configurable

## Dependencies at Risk

**None** - Zero external dependencies

The library uses only Apple frameworks (Foundation, Combine), which are stable and maintained.

## Missing Critical Features

**None detected for core functionality**

Library provides complete HTTP networking with:
- Three programming paradigms (async/await, Combine, closures)
- Automatic retry with configurable policies
- Middleware for request/response interception
- File upload/download with progress
- Thread-safe design

## Test Coverage Gaps

**Error Edge Cases:**
- What's not tested: Error cases in `ApiClient+Upload.swift` initialization (line ~87-88)
- Risk: Generic NSError thrown, behavior untested
- Priority: Low - This is a validation failure, not runtime error
- Difficulty to test: Easy - Need invalid form data input

**File Operation Failures:**
- What's not tested: Directory creation failures in download destination
- Files: `Source/Core/ApiClient+Download.swift` (lines ~259-274)
- Risk: Silent failure with generic error
- Priority: Medium - Users would get confusing errors
- Difficulty to test: Medium - Need to simulate file system failures

**Silent Form Building Failures:**
- What's not tested: Cases where UTF-8 encoding fails in multipart form
- Files: `Source/Endpoint/MultipartFormEndpoint.swift`
- Risk: Fields silently skipped
- Priority: Low - UTF-8 encoding rarely fails
- Difficulty to test: Requires injecting non-encodable strings

---

**Overall Assessment:** The codebase is well-structured with minimal technical debt. The identified concerns are minor and don't affect production stability. The library is production-ready with comprehensive test coverage for core functionality.

---

*Concerns audit: 2026-01-09*
*Update as issues are fixed or new ones discovered*
