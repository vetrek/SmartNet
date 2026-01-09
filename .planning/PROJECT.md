# SmartNet

## What This Is

A Swift HTTP networking library for iOS 13+ and macOS 10.15+ with zero external dependencies. Supports async/await, Combine, and closure-based APIs with type-safe endpoints, middleware interception, and configurable retry policies.

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

### Active

- [ ] Exact path matching for middleware (e.g., match only `/users` not `/users/123`)
- [ ] Regex path matching for middleware
- [ ] Glob pattern matching for middleware (e.g., `/users/*`, `/api/**`)
- [ ] Wildcard support in path matching

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

Current middleware system uses simple `pathComponent` string matching that checks if a path contains the component. This is insufficient for complex routing scenarios.

## Constraints

- **Zero dependencies**: Use only Foundation/Swift stdlib for pattern matching implementation
- **Backward compatibility**: Existing middleware registrations with `pathComponent: "/"` and simple strings must continue working
- **Thread safety**: Any new pattern matchers must be thread-safe
- **Platform support**: Must work on iOS 13+ and macOS 10.15+

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Focus on path matching only | User prioritizes flexible routing over control flow changes | — Pending |
| Defer middleware control features | Keep scope focused, can add in Phase 6.5 if needed | — Pending |

---
*Last updated: 2026-01-09 after initialization*
