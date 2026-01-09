//
//  PathMatcher.swift
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

import Foundation

/// A protocol that defines path matching behavior for middleware routing.
///
/// Conforming types can implement different matching strategies such as
/// exact matching, wildcard patterns, glob patterns, or regex matching.
///
/// All conforming types must be `Sendable` for thread-safe usage across
/// concurrent contexts.
public protocol PathMatcher: Sendable {
  /// The pattern string used for matching, primarily for debugging and logging.
  var pattern: String { get }

  /// Checks if the given URL path matches this matcher's pattern.
  ///
  /// - Parameter path: The URL path to match against (e.g., "/users/123/profile")
  /// - Returns: `true` if the path matches the pattern, `false` otherwise
  func matches(path: String) -> Bool
}

/// A path matcher that checks if a path contains a specific component.
///
/// This matcher replicates the existing `pathComponent` behavior:
/// - Pattern "/" matches any path (global matcher)
/// - Other patterns match if the path contains that component as a segment
///
/// Example usage:
/// ```swift
/// let matcher = ContainsPathMatcher(pattern: "users")
/// matcher.matches(path: "/users")          // true
/// matcher.matches(path: "/api/users/123")  // true
/// matcher.matches(path: "/posts")          // false
///
/// let global = ContainsPathMatcher(pattern: "/")
/// global.matches(path: "/anything")        // true
/// ```
public struct ContainsPathMatcher: PathMatcher {
  public let pattern: String

  /// Creates a new contains matcher with the specified pattern.
  ///
  /// - Parameter pattern: The path component to match. Use "/" for global matching.
  public init(pattern: String) {
    self.pattern = pattern
  }

  public func matches(path: String) -> Bool {
    // Global matcher - matches everything
    if pattern == "/" {
      return true
    }

    // Split path into components (matches URL.pathComponents behavior)
    let components = path.split(separator: "/").map(String.init)
    return components.contains(pattern)
  }
}

/// A path matcher that checks if a path matches exactly (after normalization).
///
/// This matcher normalizes both the pattern and path before comparing:
/// - Strips leading "/" from both if present
/// - Strips trailing "/" from both if present
/// - Compares strings exactly (case-sensitive)
///
/// Use this matcher when you need to target a specific path without matching
/// subpaths or parent paths.
///
/// Example usage:
/// ```swift
/// let matcher = ExactPathMatcher(pattern: "/users")
/// matcher.matches(path: "/users")          // true
/// matcher.matches(path: "/users/")         // true (trailing slash normalized)
/// matcher.matches(path: "users")           // true (leading slash normalized)
/// matcher.matches(path: "/users/123")      // false (subpath)
/// matcher.matches(path: "/api/users")      // false (different path)
///
/// let root = ExactPathMatcher(pattern: "/")
/// root.matches(path: "/")                  // true
/// root.matches(path: "")                   // true
/// root.matches(path: "/users")             // false
/// ```
public struct ExactPathMatcher: PathMatcher {
  public let pattern: String

  /// Creates a new exact matcher with the specified pattern.
  ///
  /// - Parameter pattern: The exact path to match. Use "/" for root-only matching.
  public init(pattern: String) {
    self.pattern = pattern
  }

  public func matches(path: String) -> Bool {
    let normalizedPattern = normalize(pattern)
    let normalizedPath = normalize(path)

    return normalizedPattern == normalizedPath
  }

  /// Normalizes a path by stripping leading and trailing slashes.
  private func normalize(_ path: String) -> String {
    var result = path

    // Strip leading slash
    if result.hasPrefix("/") {
      result = String(result.dropFirst())
    }

    // Strip trailing slash
    if result.hasSuffix("/") {
      result = String(result.dropLast())
    }

    return result
  }
}

/// A path matcher that supports single-segment wildcards in patterns.
///
/// This matcher uses `*` to match any single path segment. Each `*` matches
/// exactly one segment (not zero, not multiple). For multi-segment wildcards,
/// use `GlobPathMatcher` with `**` patterns.
///
/// Matching rules:
/// - Both pattern and path are split by "/" into segments
/// - Leading and trailing empty segments are stripped (normalizes slashes)
/// - Pattern and path must have the same number of segments
/// - `*` in a pattern segment matches any single path segment
/// - Non-wildcard segments must match exactly (case-sensitive)
///
/// Example usage:
/// ```swift
/// let matcher = WildcardPathMatcher(pattern: "/users/*")
/// matcher.matches(path: "/users/123")           // true
/// matcher.matches(path: "/users/abc")           // true
/// matcher.matches(path: "/users")               // false (missing segment)
/// matcher.matches(path: "/users/123/posts")     // false (too many segments)
///
/// let middle = WildcardPathMatcher(pattern: "/api/*/details")
/// middle.matches(path: "/api/users/details")    // true
/// middle.matches(path: "/api/posts/details")    // true
///
/// let multi = WildcardPathMatcher(pattern: "/*/items/*")
/// multi.matches(path: "/users/items/123")       // true
/// multi.matches(path: "/orders/items/abc")      // true
/// ```
public struct WildcardPathMatcher: PathMatcher {
  public let pattern: String

  /// Creates a new wildcard matcher with the specified pattern.
  ///
  /// - Parameter pattern: The pattern containing `*` wildcards for single-segment matching.
  public init(pattern: String) {
    self.pattern = pattern
  }

  public func matches(path: String) -> Bool {
    let patternSegments = segments(from: pattern)
    let pathSegments = segments(from: path)

    // Segment count must match (single-segment wildcard only)
    guard patternSegments.count == pathSegments.count else {
      return false
    }

    // Empty pattern only matches empty path
    if patternSegments.isEmpty {
      return pathSegments.isEmpty
    }

    // Check each segment
    for (patternSegment, pathSegment) in zip(patternSegments, pathSegments) {
      if patternSegment == "*" {
        // Wildcard matches any single segment
        continue
      } else if patternSegment != pathSegment {
        // Exact match required for non-wildcard segments
        return false
      }
    }

    return true
  }

  /// Splits a path into segments, stripping empty segments from edges.
  private func segments(from path: String) -> [String] {
    let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)

    // Strip empty segments from edges (handles leading/trailing slashes)
    var result = parts
    while result.first == "" {
      result.removeFirst()
    }
    while result.last == "" {
      result.removeLast()
    }

    return result
  }
}

/// A path matcher that supports multi-segment wildcards (`**`) in patterns.
///
/// This matcher uses `**` to match zero or more path segments, and `*` to match
/// exactly one segment. Use this for flexible path matching across nested routes.
///
/// Matching rules:
/// - `**` matches zero or more consecutive path segments
/// - `*` matches exactly one path segment (same as `WildcardPathMatcher`)
/// - Non-wildcard segments must match exactly (case-sensitive)
/// - Both pattern and path are normalized (leading/trailing slashes stripped)
///
/// Example usage:
/// ```swift
/// // Trailing **
/// let matcher = GlobPathMatcher(pattern: "/api/**")
/// matcher.matches(path: "/api")                    // true (zero segments)
/// matcher.matches(path: "/api/v1")                 // true (one segment)
/// matcher.matches(path: "/api/v1/users/123")       // true (multiple segments)
///
/// // Middle **
/// let middle = GlobPathMatcher(pattern: "/api/**/details")
/// middle.matches(path: "/api/details")             // true (zero segments)
/// middle.matches(path: "/api/v1/details")          // true (one segment)
/// middle.matches(path: "/api/v1/users/details")    // true (multiple segments)
///
/// // Leading **
/// let leading = GlobPathMatcher(pattern: "**/users")
/// leading.matches(path: "/users")                  // true
/// leading.matches(path: "/api/v1/users")           // true
///
/// // Mixed * and **
/// let mixed = GlobPathMatcher(pattern: "/api/*/v1/**")
/// mixed.matches(path: "/api/test/v1")              // true
/// mixed.matches(path: "/api/test/v1/users/123")    // true
/// ```
public struct GlobPathMatcher: PathMatcher {
  public let pattern: String

  /// Creates a new glob matcher with the specified pattern.
  ///
  /// - Parameter pattern: The pattern containing `**` for multi-segment and `*` for single-segment matching.
  public init(pattern: String) {
    self.pattern = pattern
  }

  public func matches(path: String) -> Bool {
    let patternSegments = segments(from: pattern)
    let pathSegments = segments(from: path)

    return matchSegments(patternSegments, pathSegments)
  }

  /// Recursively matches pattern segments against path segments.
  ///
  /// - Parameters:
  ///   - pattern: Remaining pattern segments to match
  ///   - path: Remaining path segments to match against
  /// - Returns: `true` if the pattern matches the path
  private func matchSegments(_ pattern: [String], _ path: [String]) -> Bool {
    var pIdx = 0  // Pattern index
    var pathIdx = 0  // Path index

    // Stack for backtracking when ** needs to consume more segments
    // Each entry is (patternIndex, pathIndex) to resume from
    var backtrackStack: [(Int, Int)] = []

    while pIdx < pattern.count || pathIdx < path.count {
      if pIdx < pattern.count {
        let segment = pattern[pIdx]

        if segment == "**" {
          // ** can match zero or more segments
          // Save backtrack point: try matching rest of pattern against rest of path
          // If that fails, we'll come back and let ** consume one more segment
          if pIdx + 1 < pattern.count {
            // More pattern after ** - save backtrack point
            backtrackStack.append((pIdx, pathIdx + 1))
          } else {
            // ** is at end of pattern - matches everything remaining
            return true
          }
          pIdx += 1
          continue
        }

        if pathIdx < path.count {
          if segment == "*" {
            // * matches exactly one segment
            pIdx += 1
            pathIdx += 1
            continue
          } else if segment == path[pathIdx] {
            // Literal match
            pIdx += 1
            pathIdx += 1
            continue
          }
        }
      }

      // No match at current position - try backtracking
      if let (savedPIdx, savedPathIdx) = backtrackStack.popLast() {
        if savedPathIdx <= path.count {
          pIdx = savedPIdx
          pathIdx = savedPathIdx
          // Re-push backtrack point for potentially consuming more
          if savedPathIdx < path.count {
            backtrackStack.append((savedPIdx, savedPathIdx + 1))
          }
          pIdx += 1  // Move past ** in pattern
          continue
        }
      }

      // No backtrack available - no match
      return false
    }

    return true
  }

  /// Splits a path into segments, stripping empty segments from edges.
  private func segments(from path: String) -> [String] {
    let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)

    // Strip empty segments from edges (handles leading/trailing slashes)
    var result = parts
    while result.first == "" {
      result.removeFirst()
    }
    while result.last == "" {
      result.removeLast()
    }

    return result
  }
}

// MARK: - Factory Methods

public extension PathMatcher where Self == ContainsPathMatcher {
  /// Creates a path matcher that checks if a path contains the specified component.
  ///
  /// This is the default matching behavior, equivalent to the legacy `pathComponent` string.
  ///
  /// - Parameter component: The path component to match. Use "/" for global matching.
  /// - Returns: A `ContainsPathMatcher` configured with the given component.
  ///
  /// Example:
  /// ```swift
  /// let matcher = PathMatcher.contains("users")
  /// ```
  static func contains(_ component: String) -> ContainsPathMatcher {
    ContainsPathMatcher(pattern: component)
  }
}

public extension PathMatcher where Self == ExactPathMatcher {
  /// Creates a path matcher that matches only the exact path (after normalization).
  ///
  /// Unlike `contains(_:)`, this matcher does not match subpaths or parent paths.
  /// Leading and trailing slashes are normalized before comparison.
  ///
  /// - Parameter path: The exact path to match. Use "/" for root-only matching.
  /// - Returns: An `ExactPathMatcher` configured with the given path.
  ///
  /// Example:
  /// ```swift
  /// let matcher = PathMatcher.exact("/users")
  /// matcher.matches(path: "/users")      // true
  /// matcher.matches(path: "/users/123")  // false
  /// ```
  static func exact(_ path: String) -> ExactPathMatcher {
    ExactPathMatcher(pattern: path)
  }
}

public extension PathMatcher where Self == WildcardPathMatcher {
  /// Creates a path matcher that supports single-segment wildcards.
  ///
  /// Use `*` to match any single path segment. The pattern and path must have
  /// the same number of segments for a match.
  ///
  /// - Parameter pattern: The pattern containing `*` wildcards.
  /// - Returns: A `WildcardPathMatcher` configured with the given pattern.
  ///
  /// Example:
  /// ```swift
  /// let matcher = PathMatcher.wildcard("/users/*")
  /// matcher.matches(path: "/users/123")      // true
  /// matcher.matches(path: "/users/123/posts")  // false
  /// ```
  static func wildcard(_ pattern: String) -> WildcardPathMatcher {
    WildcardPathMatcher(pattern: pattern)
  }
}

public extension PathMatcher where Self == GlobPathMatcher {
  /// Creates a path matcher that supports multi-segment wildcards.
  ///
  /// Use `**` to match zero or more path segments, and `*` to match exactly one.
  /// This is the most flexible matcher for hierarchical path patterns.
  ///
  /// - Parameter pattern: The pattern containing `**` and/or `*` wildcards.
  /// - Returns: A `GlobPathMatcher` configured with the given pattern.
  ///
  /// Example:
  /// ```swift
  /// let matcher = PathMatcher.glob("/api/**")
  /// matcher.matches(path: "/api")              // true
  /// matcher.matches(path: "/api/v1/users")     // true
  ///
  /// let mixed = PathMatcher.glob("/api/*/v1/**")
  /// mixed.matches(path: "/api/test/v1/users")  // true
  /// ```
  static func glob(_ pattern: String) -> GlobPathMatcher {
    GlobPathMatcher(pattern: pattern)
  }
}
