# SmartNet

## What This Is

A Swift HTTP networking library for iOS 13+ and macOS 10.15+ with zero external dependencies. Supports async/await, Combine, and closure-based APIs with type-safe endpoints, pattern-based middleware routing, and configurable retry policies. Production-ready with comprehensive documentation.

## Core Value

Provide flexible, type-safe HTTP networking that adapts to any Swift project's programming paradigm while maintaining zero dependencies and thread safety.

## Requirements

### Validated

- Type-safe HTTP networking with `Endpoint<T>` generic struct — existing
- Three programming paradigms: async/await, Combine, closures — existing
- Middleware system with path-component matching — existing
- Retry policies: exponential backoff, linear, immediate, none — existing
- `@ThreadSafe` property wrapper for concurrent access — existing
- Comprehensive error handling with `NetworkError` enum — existing
- Upload/download operations with progress tracking — existing
- `HTTPPayload` enum for body encoding (JSON, form URL encoded, multipart, raw) — existing
- `@MultipartBuilder` result builder for declarative form construction — existing
- `EndpointBuilder<T>` for fluent endpoint configuration — existing
- `SmartNetLogger` with configurable log levels via os_log — existing
- ✓ Exact path matching for middleware — v1.0
- ✓ Wildcard path matching for middleware (`/users/*`) — v1.0
- ✓ Glob pattern matching for middleware (`/api/**`) — v1.0
- ✓ Regex path matching for middleware — v1.0
- ✓ NetworkError Equatable conformance for testing — v2.0
- ✓ Complete README with PathMatcher documentation — v2.0
- ✓ DocC documentation on public APIs — v2.0
- ✓ Static factory methods for retry policies (.exponential(), .linear(), .immediate(), .none) — v2.1
- ✓ NoRetryPolicy as default (explicit opt-in for retries) — v2.1

### Active

(No active requirements — project complete for now)

### Out of Scope

- Middleware priority/ordering system — deferred to future phase
- Halting middleware pipeline — deferred to future phase
- Per-endpoint middleware configuration — deferred to future phase
- `.skip` middleware result — deferred to future phase
- `.retryWithRequest(URLRequest)` for modified retries — deferred to future phase
- Phases 7-12 (caching, security, reachability, advanced features, documentation, platforms) — future roadmap

## Context

SmartNet has completed phases 1-5 of its improvement roadmap:
- Phase 1: Critical safety fixes (force unwraps, thread safety, bugs)
- Phase 2: Test foundation (comprehensive test coverage)
- Phase 3: Error handling improvements (specific error cases, logging)
- Phase 4: Retry policies (protocol-based with configurable conditions)
- Phase 5: API modernization (typed throws, HTTPPayload, builders)

**v1.0 Advanced Path Matching shipped (2026-01-09):**
- PathMatcher protocol with extensible pattern matching system
- 5 matchers: ContainsPathMatcher, ExactPathMatcher, WildcardPathMatcher, GlobPathMatcher, RegexPathMatcher
- Factory methods: `PathMatcher.contains(_:)`, `.exact(_:)`, `.wildcard(_:)`, `.glob(_:)`, `.regex(_:)`
- Backward compatible: existing `pathComponent` continues working with deprecation warning

**v2.0 Production Ready shipped (2026-01-10):**
- API polish: 8 typo fixes, NetworkError Equatable conformance
- README overhaul: complete rewrite with PathMatcher docs, SPM-only installation
- DocC documentation on ApiClient+Async, DownloadEndpoint, QueryParameters, Response
- 11,419 LOC Swift, 305 tests

**v2.1 Retry Policy Ergonomics shipped (2026-01-10):**
- Static factory methods: `.exponential()`, `.linear()`, `.immediate()`, `.none`
- Default retry policy changed to NoRetryPolicy (explicit opt-in)
- 12,200 LOC Swift, 313 tests

## Constraints

- **Zero dependencies**: Use only Foundation/Swift stdlib for pattern matching implementation
- **Backward compatibility**: Existing middleware registrations with `pathComponent: "/"` and simple strings must continue working
- **Thread safety**: Any new pattern matchers must be thread-safe
- **Platform support**: Must work on iOS 13+ and macOS 10.15+

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Focus on path matching only | User prioritizes flexible routing over control flow changes | ✓ Good — shipped complete matching system |
| Defer middleware control features | Keep scope focused, can add in Phase 6.5 if needed | ✓ Good — scope stayed focused |
| pathMatcher property with default impl | Backward compatibility - existing code works unchanged | ✓ Good |
| pathComponent deprecated, not removed | Warns users to migrate while keeping code compiling | ✓ Good |
| Global matching via pattern "/" check | Consistent approach, ContainsPathMatcher handles actual matching | ✓ Good |
| Segment-based wildcard matching | Clear semantics: `*` = one segment, `**` = multiple | ✓ Good |
| Backtracking algorithm for glob | Efficient handling of `**` with variable segment counts | ✓ Good |
| Dual regex initializers (failable + throwing) | Different param names to avoid Swift signature collision | ✓ Good |
| SPM-only installation | CocoaPods outdated, SPM is standard | ✓ Good |
| DocC style from ApiClient+Combine | Consistent documentation across paradigms | ✓ Good |
| NoRetryPolicy as default | Explicit opt-in is safer than silent retries | ✓ Good |
| Protocol extensions with `where Self ==` | Factory methods with proper return types on `any RetryPolicy` | ✓ Good |

---
*Last updated: 2026-01-10 after v2.1 milestone*
