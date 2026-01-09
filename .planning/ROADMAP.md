# Roadmap: SmartNet Phase 6 - Advanced Path Matching

## Overview

Transform SmartNet's middleware path matching from simple string contains to a flexible, pattern-based system supporting exact matches, wildcards, globs, and regex. Each phase builds on the previous, starting with a solid protocol foundation and progressing through increasingly powerful matching capabilities.

## Domain Expertise

None

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Path Matching Foundation** - Core protocol and infrastructure for pattern matchers
- [ ] **Phase 2: Exact Path Matching** - Match exact paths only (not subpaths)
- [ ] **Phase 3: Wildcard Matching** - Single segment wildcards (`/users/*`)
- [ ] **Phase 4: Glob Pattern Matching** - Multi-segment wildcards (`/api/**`)
- [ ] **Phase 5: Regex Path Matching** - Full regex pattern support

## Phase Details

### Phase 1: Path Matching Foundation
**Goal**: Create the `PathMatcher` protocol and integrate it into the middleware system while maintaining backward compatibility with existing `pathComponent` string matching
**Depends on**: Nothing (first phase)
**Research**: Unlikely (established Swift protocol patterns)
**Plans**: TBD

Plans:
- [x] 01-01: PathMatcher protocol and ContainsPathMatcher

### Phase 2: Exact Path Matching
**Goal**: Implement `ExactPathMatcher` that matches only the exact path string (e.g., `/users` matches `/users` but not `/users/123`)
**Depends on**: Phase 1
**Research**: Unlikely (simple string comparison)
**Plans**: TBD

Plans:
- [ ] 02-01: TBD

### Phase 3: Wildcard Matching
**Goal**: Implement `WildcardPathMatcher` supporting single-segment wildcards (e.g., `/users/*` matches `/users/123` but not `/users/123/posts`)
**Depends on**: Phase 2
**Research**: Unlikely (standard glob patterns)
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

### Phase 4: Glob Pattern Matching
**Goal**: Implement `GlobPathMatcher` supporting multi-segment wildcards (e.g., `/api/**` matches `/api/v1/users/123`)
**Depends on**: Phase 3
**Research**: Unlikely (building on phase 3)
**Plans**: TBD

Plans:
- [ ] 04-01: TBD

### Phase 5: Regex Path Matching
**Goal**: Implement `RegexPathMatcher` for full regex pattern support using Foundation's NSRegularExpression
**Depends on**: Phase 4
**Research**: Unlikely (Foundation NSRegularExpression API)
**Plans**: TBD

Plans:
- [ ] 05-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Path Matching Foundation | 1/1 | Complete | 2026-01-09 |
| 2. Exact Path Matching | 0/TBD | Not started | - |
| 3. Wildcard Matching | 0/TBD | Not started | - |
| 4. Glob Pattern Matching | 0/TBD | Not started | - |
| 5. Regex Path Matching | 0/TBD | Not started | - |
