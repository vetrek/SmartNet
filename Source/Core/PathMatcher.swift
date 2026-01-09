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
