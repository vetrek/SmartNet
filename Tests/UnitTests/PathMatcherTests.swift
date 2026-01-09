//
//  PathMatcherTests.swift
//
//  Copyright (c) 2021 Valerio69 (valerio.alsebas@gmail.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Testing
import Foundation
@testable import SmartNet

@Suite("PathMatcher Tests")
struct PathMatcherTests {

  // MARK: - ContainsPathMatcher Tests

  @Test("Global matcher matches any path")
  func globalMatcherMatchesAnyPath() {
    let matcher = ContainsPathMatcher(pattern: "/")

    #expect(matcher.matches(path: "/users"))
    #expect(matcher.matches(path: "/api/v1/data"))
    #expect(matcher.matches(path: "/"))
    #expect(matcher.matches(path: "/deeply/nested/path/segment"))
    #expect(matcher.matches(path: ""))
  }

  @Test("Component matcher matches path containing component")
  func componentMatcherMatchesPathContainingComponent() {
    let matcher = ContainsPathMatcher(pattern: "users")

    #expect(matcher.matches(path: "/users"))
    #expect(matcher.matches(path: "/api/users/123"))
    #expect(matcher.matches(path: "/v1/users"))
    #expect(matcher.matches(path: "/users/profile/settings"))
  }

  @Test("Component matcher does not match unrelated paths")
  func componentMatcherDoesNotMatchUnrelatedPaths() {
    let matcher = ContainsPathMatcher(pattern: "users")

    #expect(!matcher.matches(path: "/posts"))
    #expect(!matcher.matches(path: "/api/v1/data"))
    #expect(!matcher.matches(path: "/user"))  // "user" is not "users"
    #expect(!matcher.matches(path: "/usersList"))  // partial match should not work
  }

  @Test("Component matcher is case sensitive")
  func componentMatcherIsCaseSensitive() {
    let matcher = ContainsPathMatcher(pattern: "Users")

    #expect(!matcher.matches(path: "/users"))
    #expect(!matcher.matches(path: "/USERS"))
    #expect(matcher.matches(path: "/Users"))
    #expect(matcher.matches(path: "/api/Users/123"))
  }

  @Test("Empty path handling")
  func emptyPathHandling() {
    let matcher = ContainsPathMatcher(pattern: "users")

    #expect(!matcher.matches(path: ""))
  }

  @Test("Factory method creates correct matcher")
  func factoryMethodCreatesCorrectMatcher() {
    let matcher: ContainsPathMatcher = .contains("users")

    #expect(matcher.pattern == "users")
    #expect(matcher.matches(path: "/users/123"))
    #expect(!matcher.matches(path: "/posts"))
  }

  // MARK: - Pattern Property Tests

  @Test("Pattern property returns the original pattern")
  func patternPropertyReturnsOriginalPattern() {
    let globalMatcher = ContainsPathMatcher(pattern: "/")
    #expect(globalMatcher.pattern == "/")

    let componentMatcher = ContainsPathMatcher(pattern: "api")
    #expect(componentMatcher.pattern == "api")
  }

  // MARK: - Edge Cases

  @Test("Matcher handles paths with multiple matching segments")
  func matcherHandlesMultipleMatchingSegments() {
    let matcher = ContainsPathMatcher(pattern: "api")

    // Should match even with multiple "api" segments
    #expect(matcher.matches(path: "/api/v1/api/v2"))
  }

  @Test("Matcher handles leading and trailing slashes correctly")
  func matcherHandlesSlashesCorrectly() {
    let matcher = ContainsPathMatcher(pattern: "users")

    #expect(matcher.matches(path: "/users/"))
    #expect(matcher.matches(path: "users"))
    #expect(matcher.matches(path: "/users"))
    #expect(matcher.matches(path: "users/"))
  }

  @Test("Matcher handles numeric path components")
  func matcherHandlesNumericComponents() {
    let matcher = ContainsPathMatcher(pattern: "123")

    #expect(matcher.matches(path: "/users/123"))
    #expect(matcher.matches(path: "/123/users"))
    #expect(!matcher.matches(path: "/users/1234"))
  }

  // MARK: - ExactPathMatcher Tests

  @Test("Exact matcher matches identical path")
  func exactMatcherMatchesIdenticalPath() {
    let matcher = ExactPathMatcher(pattern: "/users")

    #expect(matcher.matches(path: "/users"))
  }

  @Test("Exact matcher does not match subpaths")
  func exactMatcherDoesNotMatchSubpaths() {
    let matcher = ExactPathMatcher(pattern: "/users")

    #expect(!matcher.matches(path: "/users/123"))
    #expect(!matcher.matches(path: "/users/profile"))
    #expect(!matcher.matches(path: "/users/123/settings"))
  }

  @Test("Exact matcher does not match parent paths")
  func exactMatcherDoesNotMatchParentPaths() {
    let matcher = ExactPathMatcher(pattern: "/users/123")

    #expect(!matcher.matches(path: "/users"))
    #expect(!matcher.matches(path: "/"))
  }

  @Test("Exact matcher handles leading slash normalization")
  func exactMatcherHandlesLeadingSlashNormalization() {
    let matcherWithSlash = ExactPathMatcher(pattern: "/users")
    let matcherWithoutSlash = ExactPathMatcher(pattern: "users")

    // Pattern with leading slash matches paths with or without leading slash
    #expect(matcherWithSlash.matches(path: "/users"))
    #expect(matcherWithSlash.matches(path: "users"))

    // Pattern without leading slash matches paths with or without leading slash
    #expect(matcherWithoutSlash.matches(path: "/users"))
    #expect(matcherWithoutSlash.matches(path: "users"))
  }

  @Test("Exact matcher handles trailing slash normalization")
  func exactMatcherHandlesTrailingSlashNormalization() {
    let matcher = ExactPathMatcher(pattern: "/users")

    #expect(matcher.matches(path: "/users/"))
    #expect(matcher.matches(path: "/users"))
    #expect(matcher.matches(path: "users/"))
  }

  @Test("Exact matcher is case sensitive")
  func exactMatcherIsCaseSensitive() {
    let matcher = ExactPathMatcher(pattern: "/Users")

    #expect(!matcher.matches(path: "/users"))
    #expect(!matcher.matches(path: "/USERS"))
    #expect(matcher.matches(path: "/Users"))
  }

  @Test("Exact global pattern matches only root")
  func exactGlobalPatternMatchesOnlyRoot() {
    let matcher = ExactPathMatcher(pattern: "/")

    #expect(matcher.matches(path: "/"))
    #expect(matcher.matches(path: ""))
    #expect(!matcher.matches(path: "/users"))
    #expect(!matcher.matches(path: "/api/v1"))
  }

  @Test("Exact factory method creates correct matcher")
  func exactFactoryMethodCreatesCorrectMatcher() {
    let matcher: ExactPathMatcher = .exact("/users")

    #expect(matcher.pattern == "/users")
    #expect(matcher.matches(path: "/users"))
    #expect(!matcher.matches(path: "/users/123"))
  }

  @Test("Exact matcher handles empty path")
  func exactMatcherHandlesEmptyPath() {
    let matcher = ExactPathMatcher(pattern: "users")

    #expect(!matcher.matches(path: ""))
  }

  // MARK: - WildcardPathMatcher Tests

  @Test("Wildcard matcher matches single trailing wildcard")
  func wildcardMatcherMatchesSingleTrailingWildcard() {
    let matcher = WildcardPathMatcher(pattern: "/users/*")

    #expect(matcher.matches(path: "/users/123"))
    #expect(matcher.matches(path: "/users/abc"))
    #expect(matcher.matches(path: "/users/any-segment"))
  }

  @Test("Wildcard matcher does not match different segment counts")
  func wildcardMatcherDoesNotMatchDifferentSegmentCounts() {
    let matcher = WildcardPathMatcher(pattern: "/users/*")

    #expect(!matcher.matches(path: "/users"))  // Too few segments
    #expect(!matcher.matches(path: "/users/123/posts"))  // Too many segments
    #expect(!matcher.matches(path: "/users/123/settings/profile"))  // Too many segments
  }

  @Test("Wildcard matcher matches middle wildcard")
  func wildcardMatcherMatchesMiddleWildcard() {
    let matcher = WildcardPathMatcher(pattern: "/api/*/details")

    #expect(matcher.matches(path: "/api/users/details"))
    #expect(matcher.matches(path: "/api/posts/details"))
    #expect(matcher.matches(path: "/api/123/details"))
  }

  @Test("Wildcard matcher matches multiple wildcards")
  func wildcardMatcherMatchesMultipleWildcards() {
    let matcher = WildcardPathMatcher(pattern: "/*/items/*")

    #expect(matcher.matches(path: "/users/items/123"))
    #expect(matcher.matches(path: "/orders/items/abc"))
    #expect(matcher.matches(path: "/any/items/thing"))
  }

  @Test("Wildcard matcher matches wildcard at start")
  func wildcardMatcherMatchesWildcardAtStart() {
    let matcher = WildcardPathMatcher(pattern: "*/users")

    #expect(matcher.matches(path: "api/users"))
    #expect(matcher.matches(path: "v1/users"))
    #expect(matcher.matches(path: "/v2/users"))  // Leading slash normalized
  }

  @Test("Wildcard matcher single wildcard pattern")
  func wildcardMatcherSingleWildcardPattern() {
    let matcher = WildcardPathMatcher(pattern: "*")

    #expect(matcher.matches(path: "anything"))
    #expect(matcher.matches(path: "users"))
    #expect(matcher.matches(path: "/segment"))  // Normalizes to "segment"
    #expect(!matcher.matches(path: "a/b"))  // Two segments
    #expect(!matcher.matches(path: "/a/b"))  // Two segments
  }

  @Test("Wildcard matcher handles leading and trailing slash normalization")
  func wildcardMatcherHandlesSlashNormalization() {
    let matcher = WildcardPathMatcher(pattern: "/users/*/profile")

    #expect(matcher.matches(path: "/users/123/profile"))
    #expect(matcher.matches(path: "users/123/profile"))  // No leading slash
    #expect(matcher.matches(path: "/users/123/profile/"))  // Trailing slash
    #expect(matcher.matches(path: "users/123/profile/"))  // Both
  }

  @Test("Wildcard matcher is case sensitive for non-wildcard segments")
  func wildcardMatcherIsCaseSensitive() {
    let matcher = WildcardPathMatcher(pattern: "/Users/*")

    #expect(matcher.matches(path: "/Users/123"))
    #expect(!matcher.matches(path: "/users/123"))  // lowercase "users" doesn't match "Users"
    #expect(!matcher.matches(path: "/USERS/123"))  // uppercase doesn't match
  }

  @Test("Wildcard matcher handles empty path")
  func wildcardMatcherHandlesEmptyPath() {
    let matcher = WildcardPathMatcher(pattern: "/users/*")

    #expect(!matcher.matches(path: ""))
  }

  @Test("Wildcard matcher empty pattern matches empty path")
  func wildcardMatcherEmptyPatternMatchesEmptyPath() {
    let matcher = WildcardPathMatcher(pattern: "")

    #expect(matcher.matches(path: ""))
    #expect(matcher.matches(path: "/"))  // Normalizes to empty
    #expect(!matcher.matches(path: "/users"))
  }

  @Test("Wildcard factory method creates correct matcher")
  func wildcardFactoryMethodCreatesCorrectMatcher() {
    let matcher: WildcardPathMatcher = .wildcard("/users/*")

    #expect(matcher.pattern == "/users/*")
    #expect(matcher.matches(path: "/users/123"))
    #expect(!matcher.matches(path: "/users/123/posts"))
  }

  @Test("Wildcard matcher pattern property returns original pattern")
  func wildcardMatcherPatternPropertyReturnsOriginalPattern() {
    let matcher = WildcardPathMatcher(pattern: "/api/*/details")
    #expect(matcher.pattern == "/api/*/details")

    let starMatcher = WildcardPathMatcher(pattern: "*")
    #expect(starMatcher.pattern == "*")
  }

  // MARK: - GlobPathMatcher Tests

  @Test("Glob matcher matches trailing ** pattern")
  func globMatcherMatchesTrailingDoubleWildcard() {
    let matcher = GlobPathMatcher(pattern: "/api/**")

    // ** matches zero or more segments
    #expect(matcher.matches(path: "/api"))  // Zero segments after api
    #expect(matcher.matches(path: "/api/v1"))  // One segment
    #expect(matcher.matches(path: "/api/v1/users"))  // Two segments
    #expect(matcher.matches(path: "/api/v1/users/123"))  // Three segments
  }

  @Test("Glob matcher trailing ** does not match different prefix")
  func globMatcherTrailingDoesNotMatchDifferentPrefix() {
    let matcher = GlobPathMatcher(pattern: "/api/**")

    #expect(!matcher.matches(path: "/other"))
    #expect(!matcher.matches(path: "/apiv2"))  // Not a segment match
    #expect(!matcher.matches(path: "/other/api/v1"))  // api not at right position
  }

  @Test("Glob matcher matches middle ** pattern")
  func globMatcherMatchesMiddleDoubleWildcard() {
    let matcher = GlobPathMatcher(pattern: "/api/**/details")

    // ** matches zero or more segments in the middle
    #expect(matcher.matches(path: "/api/details"))  // Zero segments
    #expect(matcher.matches(path: "/api/v1/details"))  // One segment
    #expect(matcher.matches(path: "/api/v1/users/details"))  // Two segments
    #expect(matcher.matches(path: "/api/v1/users/123/details"))  // Three segments
  }

  @Test("Glob matcher middle ** does not match wrong ending")
  func globMatcherMiddleDoesNotMatchWrongEnding() {
    let matcher = GlobPathMatcher(pattern: "/api/**/details")

    #expect(!matcher.matches(path: "/api/v1/other"))
    #expect(!matcher.matches(path: "/api/v1/detailsX"))  // Not exact match
    #expect(!matcher.matches(path: "/other/details"))  // Wrong prefix
  }

  @Test("Glob matcher matches leading ** pattern")
  func globMatcherMatchesLeadingDoubleWildcard() {
    let matcher = GlobPathMatcher(pattern: "**/users")

    // ** matches zero or more segments at start
    #expect(matcher.matches(path: "/users"))  // Zero segments before
    #expect(matcher.matches(path: "/api/users"))  // One segment before
    #expect(matcher.matches(path: "/api/v1/users"))  // Two segments before
  }

  @Test("Glob matcher leading ** does not match wrong ending")
  func globMatcherLeadingDoesNotMatchWrongEnding() {
    let matcher = GlobPathMatcher(pattern: "**/users")

    #expect(!matcher.matches(path: "/users/123"))  // Extra segment after
    #expect(!matcher.matches(path: "/api/user"))  // Not "users"
  }

  @Test("Glob matcher matches multiple ** patterns")
  func globMatcherMatchesMultipleDoubleWildcards() {
    let matcher = GlobPathMatcher(pattern: "/**/api/**")

    #expect(matcher.matches(path: "/api"))  // Zero on both sides
    #expect(matcher.matches(path: "/v1/api"))  // One before, zero after
    #expect(matcher.matches(path: "/api/users"))  // Zero before, one after
    #expect(matcher.matches(path: "/v1/api/users"))  // One on each side
    #expect(matcher.matches(path: "/v1/v2/api/users/123"))  // Multiple on each side
  }

  @Test("Glob matcher matches mixed * and ** patterns")
  func globMatcherMatchesMixedWildcards() {
    let matcher = GlobPathMatcher(pattern: "/api/*/v1/**")

    // * requires exactly one segment, ** allows zero or more
    #expect(matcher.matches(path: "/api/test/v1"))  // * matches "test", ** matches zero
    #expect(matcher.matches(path: "/api/prod/v1/users"))  // ** matches one
    #expect(matcher.matches(path: "/api/staging/v1/users/123"))  // ** matches two
  }

  @Test("Glob matcher mixed wildcards * still requires one segment")
  func globMatcherMixedWildcardsSingleRequiresSegment() {
    let matcher = GlobPathMatcher(pattern: "/api/*/v1/**")

    #expect(!matcher.matches(path: "/api/v1"))  // Missing segment for *
    #expect(!matcher.matches(path: "/api/v1/users"))  // Missing segment for *
  }

  @Test("Glob matcher ** alone matches any path")
  func globMatcherDoubleWildcardAloneMatchesAny() {
    let matcher = GlobPathMatcher(pattern: "**")

    #expect(matcher.matches(path: ""))
    #expect(matcher.matches(path: "/"))
    #expect(matcher.matches(path: "/users"))
    #expect(matcher.matches(path: "/api/v1/users/123"))
  }

  @Test("Glob matcher handles empty pattern")
  func globMatcherHandlesEmptyPattern() {
    let matcher = GlobPathMatcher(pattern: "")

    #expect(matcher.matches(path: ""))
    #expect(matcher.matches(path: "/"))  // Normalizes to empty
    #expect(!matcher.matches(path: "/users"))
  }

  @Test("Glob matcher handles slash normalization")
  func globMatcherHandlesSlashNormalization() {
    let matcher = GlobPathMatcher(pattern: "/api/**/details")

    #expect(matcher.matches(path: "/api/v1/details"))
    #expect(matcher.matches(path: "api/v1/details"))  // No leading slash
    #expect(matcher.matches(path: "/api/v1/details/"))  // Trailing slash
    #expect(matcher.matches(path: "api/v1/details/"))  // Both
  }

  @Test("Glob matcher is case sensitive for literal segments")
  func globMatcherIsCaseSensitive() {
    let matcher = GlobPathMatcher(pattern: "/Api/**/Details")

    #expect(matcher.matches(path: "/Api/v1/Details"))
    #expect(!matcher.matches(path: "/api/v1/details"))  // Lowercase doesn't match
    #expect(!matcher.matches(path: "/API/v1/DETAILS"))  // Uppercase doesn't match
  }

  @Test("Glob factory method creates correct matcher")
  func globFactoryMethodCreatesCorrectMatcher() {
    let matcher: GlobPathMatcher = .glob("/api/**")

    #expect(matcher.pattern == "/api/**")
    #expect(matcher.matches(path: "/api/v1/users"))
    #expect(!matcher.matches(path: "/other"))
  }

  @Test("Glob matcher pattern property returns original pattern")
  func globMatcherPatternPropertyReturnsOriginalPattern() {
    let matcher = GlobPathMatcher(pattern: "/api/**/details")
    #expect(matcher.pattern == "/api/**/details")

    let starMatcher = GlobPathMatcher(pattern: "**")
    #expect(starMatcher.pattern == "**")
  }

  @Test("Glob matcher handles complex nested patterns")
  func globMatcherHandlesComplexNestedPatterns() {
    let matcher = GlobPathMatcher(pattern: "/api/*/v*/**/end")

    // This tests * matching segments with literal characters mixed
    // Note: * matches entire segment, not partial - so v* is literal "v*"
    #expect(!matcher.matches(path: "/api/test/v1/end"))  // "v1" != "v*"
  }

  @Test("Glob matcher ** at multiple positions")
  func globMatcherMultipleDoubleWildcardsAtDifferentPositions() {
    let matcher = GlobPathMatcher(pattern: "/**/middle/**")

    #expect(matcher.matches(path: "/middle"))  // Zero on both sides
    #expect(matcher.matches(path: "/a/middle"))
    #expect(matcher.matches(path: "/middle/b"))
    #expect(matcher.matches(path: "/a/middle/b"))
    #expect(matcher.matches(path: "/a/b/middle/c/d"))
  }
}
