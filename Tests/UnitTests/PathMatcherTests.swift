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
}
