//
//  RetryPolicy.swift
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

// MARK: - RetryPolicy Protocol

/// A protocol that defines retry behavior for network requests.
///
/// Conforming types determine when a failed request should be retried,
/// how many times, and with what delay between attempts.
public protocol RetryPolicy: Sendable {
  /// Maximum number of retry attempts (not including the initial request).
  var maxRetries: Int { get }

  /// Determines whether the given error should trigger a retry.
  /// - Parameters:
  ///   - error: The error that occurred.
  ///   - attempt: The current attempt number (0-indexed, where 0 is the first retry).
  /// - Returns: `true` if the request should be retried, `false` otherwise.
  func shouldRetry(for error: NetworkError, attempt: Int) -> Bool

  /// Calculates the delay before the next retry attempt.
  /// - Parameters:
  ///   - attempt: The current attempt number (0-indexed).
  ///   - error: The error that occurred (useful for rate limiting).
  /// - Returns: The time interval to wait before retrying.
  func delay(forAttempt attempt: Int, error: NetworkError?) -> TimeInterval
}

// MARK: - Default Implementation

public extension RetryPolicy {
  func delay(forAttempt attempt: Int, error: NetworkError?) -> TimeInterval {
    delay(forAttempt: attempt, error: nil)
  }
}

// MARK: - RetryCondition

/// Defines conditions under which a request should be retried.
public struct RetryCondition: OptionSet, Sendable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  /// Retry on timeout errors
  public static let timeout = RetryCondition(rawValue: 1 << 0)

  /// Retry when network connection is lost
  public static let connectionLost = RetryCondition(rawValue: 1 << 1)

  /// Retry on general network failures
  public static let networkFailure = RetryCondition(rawValue: 1 << 2)

  /// Retry on 5xx server errors
  public static let serverError = RetryCondition(rawValue: 1 << 3)

  /// Retry on rate limiting (429)
  public static let rateLimited = RetryCondition(rawValue: 1 << 4)

  /// Retry on DNS lookup failures
  public static let dnsFailure = RetryCondition(rawValue: 1 << 5)

  /// Default conditions: timeout, connectionLost, networkFailure, serverError
  public static let `default`: RetryCondition = [.timeout, .connectionLost, .networkFailure, .serverError]

  /// All retryable conditions
  public static let all: RetryCondition = [.timeout, .connectionLost, .networkFailure, .serverError, .rateLimited, .dnsFailure]

  /// No retry conditions (never retry)
  public static let none: RetryCondition = []
}

// MARK: - ExponentialBackoffRetryPolicy

/// A retry policy that uses exponential backoff with optional jitter.
///
/// Delays increase exponentially: baseDelay * 2^attempt
/// With jitter enabled, adds randomness to prevent thundering herd.
public struct ExponentialBackoffRetryPolicy: RetryPolicy {
  public let maxRetries: Int
  public let baseDelay: TimeInterval
  public let maxDelay: TimeInterval
  public let jitter: Bool
  public let conditions: RetryCondition

  /// Creates an exponential backoff retry policy.
  /// - Parameters:
  ///   - maxRetries: Maximum retry attempts. Default is 3.
  ///   - baseDelay: Initial delay in seconds. Default is 1.0.
  ///   - maxDelay: Maximum delay cap in seconds. Default is 60.0.
  ///   - jitter: Whether to add randomness to delays. Default is true.
  ///   - conditions: Conditions under which to retry. Default is `.default`.
  public init(
    maxRetries: Int = 3,
    baseDelay: TimeInterval = 1.0,
    maxDelay: TimeInterval = 60.0,
    jitter: Bool = true,
    conditions: RetryCondition = .default
  ) {
    self.maxRetries = max(0, maxRetries)
    self.baseDelay = max(0, baseDelay)
    self.maxDelay = max(self.baseDelay, max(0, maxDelay))
    self.jitter = jitter
    self.conditions = conditions
  }

  public func shouldRetry(for error: NetworkError, attempt: Int) -> Bool {
    guard attempt < maxRetries else { return false }
    return error.matchesCondition(conditions)
  }

  public func delay(forAttempt attempt: Int, error: NetworkError?) -> TimeInterval {
    // Handle rate limiting with server-provided delay
    if let error = error, case .rateLimited(let retryAfter) = error, let serverDelay = retryAfter {
      return serverDelay
    }

    // Calculate exponential delay: baseDelay * 2^attempt
    let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
    let cappedDelay = min(exponentialDelay, maxDelay)

    if jitter {
      // Add jitter: random value between 0 and cappedDelay
      let jitterRange = cappedDelay * 0.5
      let randomJitter = Double.random(in: -jitterRange...jitterRange)
      return max(0, cappedDelay + randomJitter)
    }

    return cappedDelay
  }
}

// MARK: - LinearBackoffRetryPolicy

/// A retry policy that uses linear backoff.
///
/// Delays increase linearly: delay * (attempt + 1)
public struct LinearBackoffRetryPolicy: RetryPolicy {
  public let maxRetries: Int
  public let delay: TimeInterval
  public let conditions: RetryCondition

  /// Creates a linear backoff retry policy.
  /// - Parameters:
  ///   - maxRetries: Maximum retry attempts. Default is 3.
  ///   - delay: Base delay in seconds. Default is 1.0.
  ///   - conditions: Conditions under which to retry. Default is `.default`.
  public init(
    maxRetries: Int = 3,
    delay: TimeInterval = 1.0,
    conditions: RetryCondition = .default
  ) {
    self.maxRetries = max(0, maxRetries)
    self.delay = max(0, delay)
    self.conditions = conditions
  }

  public func shouldRetry(for error: NetworkError, attempt: Int) -> Bool {
    guard attempt < maxRetries else { return false }
    return error.matchesCondition(conditions)
  }

  public func delay(forAttempt attempt: Int, error: NetworkError?) -> TimeInterval {
    // Handle rate limiting with server-provided delay
    if let error = error, case .rateLimited(let retryAfter) = error, let serverDelay = retryAfter {
      return serverDelay
    }

    return delay * Double(attempt + 1)
  }
}

// MARK: - ImmediateRetryPolicy

/// A retry policy that retries immediately without delay.
public struct ImmediateRetryPolicy: RetryPolicy {
  public let maxRetries: Int
  public let conditions: RetryCondition

  /// Creates an immediate retry policy.
  /// - Parameters:
  ///   - maxRetries: Maximum retry attempts. Default is 1.
  ///   - conditions: Conditions under which to retry. Default is `.default`.
  public init(
    maxRetries: Int = 1,
    conditions: RetryCondition = .default
  ) {
    self.maxRetries = max(0, maxRetries)
    self.conditions = conditions
  }

  public func shouldRetry(for error: NetworkError, attempt: Int) -> Bool {
    guard attempt < maxRetries else { return false }
    return error.matchesCondition(conditions)
  }

  public func delay(forAttempt attempt: Int, error: NetworkError?) -> TimeInterval {
    // Handle rate limiting with server-provided delay
    if let error = error, case .rateLimited(let retryAfter) = error, let serverDelay = retryAfter {
      return serverDelay
    }
    return 0
  }
}

// MARK: - NoRetryPolicy

/// A retry policy that never retries.
public struct NoRetryPolicy: RetryPolicy {
  public let maxRetries: Int = 0

  public init() {}

  public func shouldRetry(for error: NetworkError, attempt: Int) -> Bool {
    false
  }

  public func delay(forAttempt attempt: Int, error: NetworkError?) -> TimeInterval {
    0
  }
}

// MARK: - NetworkError Extension

extension NetworkError {
  /// Checks if this error matches any of the given retry conditions.
  func matchesCondition(_ condition: RetryCondition) -> Bool {
    switch self {
    case .timeout:
      return condition.contains(.timeout)

    case .connectionLost:
      return condition.contains(.connectionLost)

    case .networkFailure:
      return condition.contains(.networkFailure)

    case .dnsLookupFailed:
      return condition.contains(.dnsFailure)

    case .rateLimited:
      return condition.contains(.rateLimited)

    case .error(let statusCode, _):
      // 5xx server errors
      if (500...599).contains(statusCode) {
        return condition.contains(.serverError)
      }
      return false

    case .cancelled, .parsingFailed, .emptyResponse, .urlGeneration,
         .dataToStringFailure, .middleware, .generic, .sslError,
         .middlewareMaxRetry, .unableToSaveFile, .parsedError,
         .invalidSessions, .invalidDownloadUrl, .invalidDownloadFileData,
         .invalidFormData:
      return false
    }
  }
}
