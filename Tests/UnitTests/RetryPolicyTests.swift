//
//  RetryPolicyTests.swift
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
import Testing
@testable import SmartNet

// MARK: - ExponentialBackoffRetryPolicy Tests

@Suite("ExponentialBackoffRetryPolicy Tests")
struct ExponentialBackoffRetryPolicyTests {

  @Test("Default initialization values")
  func defaultValues() {
    let policy = ExponentialBackoffRetryPolicy()

    #expect(policy.maxRetries == 3)
    #expect(policy.baseDelay == 1.0)
    #expect(policy.maxDelay == 60.0)
    #expect(policy.jitter == true)
    #expect(policy.conditions == .default)
  }

  @Test("Custom initialization values")
  func customValues() {
    let policy = ExponentialBackoffRetryPolicy(
      maxRetries: 5,
      baseDelay: 2.0,
      maxDelay: 30.0,
      jitter: false,
      conditions: .all
    )

    #expect(policy.maxRetries == 5)
    #expect(policy.baseDelay == 2.0)
    #expect(policy.maxDelay == 30.0)
    #expect(policy.jitter == false)
    #expect(policy.conditions == .all)
  }

  @Test("Delay calculation without jitter")
  func delayWithoutJitter() {
    let policy = ExponentialBackoffRetryPolicy(
      maxRetries: 5,
      baseDelay: 1.0,
      maxDelay: 60.0,
      jitter: false
    )

    // baseDelay * 2^attempt
    #expect(policy.delay(forAttempt: 0, error: nil) == 1.0)   // 1 * 2^0 = 1
    #expect(policy.delay(forAttempt: 1, error: nil) == 2.0)   // 1 * 2^1 = 2
    #expect(policy.delay(forAttempt: 2, error: nil) == 4.0)   // 1 * 2^2 = 4
    #expect(policy.delay(forAttempt: 3, error: nil) == 8.0)   // 1 * 2^3 = 8
    #expect(policy.delay(forAttempt: 4, error: nil) == 16.0)  // 1 * 2^4 = 16
  }

  @Test("Delay capped at maxDelay")
  func delayCappedAtMax() {
    let policy = ExponentialBackoffRetryPolicy(
      maxRetries: 10,
      baseDelay: 1.0,
      maxDelay: 10.0,
      jitter: false
    )

    #expect(policy.delay(forAttempt: 5, error: nil) == 10.0)  // 1 * 2^5 = 32, capped to 10
    #expect(policy.delay(forAttempt: 10, error: nil) == 10.0) // 1 * 2^10 = 1024, capped to 10
  }

  @Test("Delay with jitter adds randomness")
  func delayWithJitter() {
    let policy = ExponentialBackoffRetryPolicy(
      maxRetries: 3,
      baseDelay: 1.0,
      maxDelay: 60.0,
      jitter: true
    )

    // With jitter, delay should vary between calls
    var delays: Set<TimeInterval> = []
    for _ in 0..<10 {
      delays.insert(policy.delay(forAttempt: 1, error: nil))
    }

    // With 10 samples, we expect some variation (not all identical)
    // In practice, with jitter this should produce multiple unique values
    #expect(delays.count > 1, "Jitter should produce varying delays")
  }

  @Test("Rate limited error uses server-provided delay")
  func rateLimitedUsesServerDelay() {
    let policy = ExponentialBackoffRetryPolicy(
      maxRetries: 3,
      baseDelay: 1.0,
      jitter: false
    )

    let error = NetworkError.rateLimited(retryAfter: 120.0)
    let delay = policy.delay(forAttempt: 0, error: error)

    #expect(delay == 120.0)
  }

  @Test("shouldRetry respects maxRetries")
  func shouldRetryRespectsMaxRetries() {
    let policy = ExponentialBackoffRetryPolicy(maxRetries: 2)

    #expect(policy.shouldRetry(for: .timeout, attempt: 0) == true)
    #expect(policy.shouldRetry(for: .timeout, attempt: 1) == true)
    #expect(policy.shouldRetry(for: .timeout, attempt: 2) == false)
    #expect(policy.shouldRetry(for: .timeout, attempt: 3) == false)
  }

  @Test("shouldRetry checks error conditions")
  func shouldRetryChecksConditions() {
    let policy = ExponentialBackoffRetryPolicy(
      maxRetries: 3,
      conditions: [.timeout, .serverError]
    )

    #expect(policy.shouldRetry(for: .timeout, attempt: 0) == true)
    #expect(policy.shouldRetry(for: .error(statusCode: 500, data: nil), attempt: 0) == true)
    #expect(policy.shouldRetry(for: .error(statusCode: 503, data: nil), attempt: 0) == true)
    #expect(policy.shouldRetry(for: .networkFailure, attempt: 0) == false)
    #expect(policy.shouldRetry(for: .connectionLost, attempt: 0) == false)
    #expect(policy.shouldRetry(for: .cancelled, attempt: 0) == false)
  }

  @Test("Negative values are clamped to zero")
  func negativeValuesClamped() {
    let policy = ExponentialBackoffRetryPolicy(
      maxRetries: -5,
      baseDelay: -1.0,
      maxDelay: -10.0
    )

    #expect(policy.maxRetries == 0)
    #expect(policy.baseDelay == 0)
    #expect(policy.maxDelay == 0)
  }
}

// MARK: - LinearBackoffRetryPolicy Tests

@Suite("LinearBackoffRetryPolicy Tests")
struct LinearBackoffRetryPolicyTests {

  @Test("Default initialization values")
  func defaultValues() {
    let policy = LinearBackoffRetryPolicy()

    #expect(policy.maxRetries == 3)
    #expect(policy.delay == 1.0)
    #expect(policy.conditions == .default)
  }

  @Test("Linear delay calculation")
  func linearDelay() {
    let policy = LinearBackoffRetryPolicy(
      maxRetries: 5,
      delay: 2.0
    )

    // delay * (attempt + 1)
    #expect(policy.delay(forAttempt: 0, error: nil) == 2.0)   // 2 * 1
    #expect(policy.delay(forAttempt: 1, error: nil) == 4.0)   // 2 * 2
    #expect(policy.delay(forAttempt: 2, error: nil) == 6.0)   // 2 * 3
    #expect(policy.delay(forAttempt: 3, error: nil) == 8.0)   // 2 * 4
    #expect(policy.delay(forAttempt: 4, error: nil) == 10.0)  // 2 * 5
  }

  @Test("Rate limited error uses server-provided delay")
  func rateLimitedUsesServerDelay() {
    let policy = LinearBackoffRetryPolicy(maxRetries: 3, delay: 1.0)

    let error = NetworkError.rateLimited(retryAfter: 60.0)
    let delay = policy.delay(forAttempt: 0, error: error)

    #expect(delay == 60.0)
  }

  @Test("shouldRetry respects conditions")
  func shouldRetryRespectsConditions() {
    let policy = LinearBackoffRetryPolicy(conditions: [.connectionLost])

    #expect(policy.shouldRetry(for: .connectionLost, attempt: 0) == true)
    #expect(policy.shouldRetry(for: .timeout, attempt: 0) == false)
  }
}

// MARK: - ImmediateRetryPolicy Tests

@Suite("ImmediateRetryPolicy Tests")
struct ImmediateRetryPolicyTests {

  @Test("Default initialization values")
  func defaultValues() {
    let policy = ImmediateRetryPolicy()

    #expect(policy.maxRetries == 1)
    #expect(policy.conditions == .default)
  }

  @Test("Delay is always zero")
  func zeroDelay() {
    let policy = ImmediateRetryPolicy(maxRetries: 5)

    #expect(policy.delay(forAttempt: 0, error: nil) == 0)
    #expect(policy.delay(forAttempt: 1, error: nil) == 0)
    #expect(policy.delay(forAttempt: 2, error: nil) == 0)
  }

  @Test("Rate limited error uses server-provided delay")
  func rateLimitedUsesServerDelay() {
    let policy = ImmediateRetryPolicy(maxRetries: 3)

    let error = NetworkError.rateLimited(retryAfter: 30.0)
    let delay = policy.delay(forAttempt: 0, error: error)

    #expect(delay == 30.0)
  }
}

// MARK: - NoRetryPolicy Tests

@Suite("NoRetryPolicy Tests")
struct NoRetryPolicyTests {

  @Test("maxRetries is always zero")
  func maxRetriesZero() {
    let policy = NoRetryPolicy()
    #expect(policy.maxRetries == 0)
  }

  @Test("shouldRetry always returns false")
  func neverRetries() {
    let policy = NoRetryPolicy()

    #expect(policy.shouldRetry(for: .timeout, attempt: 0) == false)
    #expect(policy.shouldRetry(for: .networkFailure, attempt: 0) == false)
    #expect(policy.shouldRetry(for: .connectionLost, attempt: 0) == false)
    #expect(policy.shouldRetry(for: .error(statusCode: 500, data: nil), attempt: 0) == false)
  }

  @Test("Delay is always zero")
  func zeroDelay() {
    let policy = NoRetryPolicy()

    #expect(policy.delay(forAttempt: 0, error: nil) == 0)
    #expect(policy.delay(forAttempt: 1, error: nil) == 0)
  }
}

// MARK: - RetryCondition Tests

@Suite("RetryCondition Tests")
struct RetryConditionTests {

  @Test("Default conditions include expected values")
  func defaultConditions() {
    let defaultConditions = RetryCondition.default

    #expect(defaultConditions.contains(.timeout))
    #expect(defaultConditions.contains(.connectionLost))
    #expect(defaultConditions.contains(.networkFailure))
    #expect(defaultConditions.contains(.serverError))
    #expect(!defaultConditions.contains(.rateLimited))
    #expect(!defaultConditions.contains(.dnsFailure))
  }

  @Test("All conditions include everything")
  func allConditions() {
    let allConditions = RetryCondition.all

    #expect(allConditions.contains(.timeout))
    #expect(allConditions.contains(.connectionLost))
    #expect(allConditions.contains(.networkFailure))
    #expect(allConditions.contains(.serverError))
    #expect(allConditions.contains(.rateLimited))
    #expect(allConditions.contains(.dnsFailure))
  }

  @Test("None conditions are empty")
  func noneConditions() {
    let noneConditions = RetryCondition.none

    #expect(!noneConditions.contains(.timeout))
    #expect(!noneConditions.contains(.connectionLost))
    #expect(!noneConditions.contains(.networkFailure))
    #expect(!noneConditions.contains(.serverError))
    #expect(!noneConditions.contains(.rateLimited))
    #expect(!noneConditions.contains(.dnsFailure))
  }

  @Test("Combining conditions")
  func combiningConditions() {
    let combined: RetryCondition = [.timeout, .rateLimited]

    #expect(combined.contains(.timeout))
    #expect(combined.contains(.rateLimited))
    #expect(!combined.contains(.serverError))
    #expect(!combined.contains(.networkFailure))
  }
}

// MARK: - NetworkError Condition Matching Tests

@Suite("NetworkError Condition Matching Tests")
struct NetworkErrorConditionMatchingTests {

  @Test("Timeout matches timeout condition")
  func timeoutMatches() {
    #expect(NetworkError.timeout.matchesCondition(.timeout))
    #expect(!NetworkError.timeout.matchesCondition(.serverError))
  }

  @Test("ConnectionLost matches connectionLost condition")
  func connectionLostMatches() {
    #expect(NetworkError.connectionLost.matchesCondition(.connectionLost))
    #expect(!NetworkError.connectionLost.matchesCondition(.timeout))
  }

  @Test("NetworkFailure matches networkFailure condition")
  func networkFailureMatches() {
    #expect(NetworkError.networkFailure.matchesCondition(.networkFailure))
    #expect(!NetworkError.networkFailure.matchesCondition(.serverError))
  }

  @Test("DNS lookup failed matches dnsFailure condition")
  func dnsFailureMatches() {
    #expect(NetworkError.dnsLookupFailed.matchesCondition(.dnsFailure))
    #expect(!NetworkError.dnsLookupFailed.matchesCondition(.timeout))
  }

  @Test("RateLimited matches rateLimited condition")
  func rateLimitedMatches() {
    #expect(NetworkError.rateLimited(retryAfter: 60).matchesCondition(.rateLimited))
    #expect(NetworkError.rateLimited(retryAfter: nil).matchesCondition(.rateLimited))
    #expect(!NetworkError.rateLimited(retryAfter: 60).matchesCondition(.serverError))
  }

  @Test("5xx errors match serverError condition")
  func serverErrorMatches() {
    #expect(NetworkError.error(statusCode: 500, data: nil).matchesCondition(.serverError))
    #expect(NetworkError.error(statusCode: 502, data: nil).matchesCondition(.serverError))
    #expect(NetworkError.error(statusCode: 503, data: nil).matchesCondition(.serverError))
    #expect(NetworkError.error(statusCode: 599, data: nil).matchesCondition(.serverError))
  }

  @Test("4xx errors do not match serverError condition")
  func clientErrorDoesNotMatch() {
    #expect(!NetworkError.error(statusCode: 400, data: nil).matchesCondition(.serverError))
    #expect(!NetworkError.error(statusCode: 401, data: nil).matchesCondition(.serverError))
    #expect(!NetworkError.error(statusCode: 404, data: nil).matchesCondition(.serverError))
    #expect(!NetworkError.error(statusCode: 499, data: nil).matchesCondition(.serverError))
  }

  @Test("Non-retryable errors don't match any condition")
  func nonRetryableErrors() {
    let conditions = RetryCondition.all

    #expect(!NetworkError.cancelled.matchesCondition(conditions))
    #expect(!NetworkError.parsingFailed.matchesCondition(conditions))
    #expect(!NetworkError.emptyResponse.matchesCondition(conditions))
    #expect(!NetworkError.urlGeneration.matchesCondition(conditions))
    #expect(!NetworkError.middlewareMaxRetry.matchesCondition(conditions))
    #expect(!NetworkError.sslError(nil).matchesCondition(conditions))
  }
}

// MARK: - Integration with Endpoint Tests

@Suite("Endpoint RetryPolicy Integration Tests")
struct EndpointRetryPolicyTests {

  @Test("Endpoint defaults to nil retryPolicy")
  func endpointDefaultsToNil() {
    let endpoint = Endpoint<Data>(path: "/test", method: .get)
    #expect(endpoint.retryPolicy == nil)
  }

  @Test("Endpoint can have custom retryPolicy")
  func endpointCustomPolicy() {
    let customPolicy = NoRetryPolicy()
    let endpoint = Endpoint<Data>(
      path: "/test",
      method: .get,
      retryPolicy: customPolicy
    )

    #expect(endpoint.retryPolicy != nil)
    #expect(endpoint.retryPolicy?.maxRetries == 0)
  }

  @Test("Endpoint with immediate retry policy")
  func endpointWithImmediateRetry() {
    let policy = ImmediateRetryPolicy(maxRetries: 5)
    let endpoint = Endpoint<Data>(
      path: "/critical",
      method: .post,
      retryPolicy: policy
    )

    #expect(endpoint.retryPolicy?.maxRetries == 5)
  }
}

// MARK: - NetworkConfiguration RetryPolicy Tests

@Suite("NetworkConfiguration RetryPolicy Tests")
struct NetworkConfigurationRetryPolicyTests {

  @Test("Default configuration uses ExponentialBackoffRetryPolicy")
  func defaultRetryPolicy() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)

    #expect(config.retryPolicy.maxRetries == 3)
    // Default is ExponentialBackoffRetryPolicy
    #expect(config.retryPolicy is ExponentialBackoffRetryPolicy)
  }

  @Test("Configuration with custom retry policy")
  func customRetryPolicy() {
    let customPolicy = LinearBackoffRetryPolicy(maxRetries: 5, delay: 2.0)
    let config = NetworkConfiguration(
      baseURL: URL(string: "https://api.example.com")!,
      retryPolicy: customPolicy
    )

    #expect(config.retryPolicy.maxRetries == 5)
    #expect(config.retryPolicy is LinearBackoffRetryPolicy)
  }

  @Test("Configuration with no retry policy")
  func noRetryPolicy() {
    let config = NetworkConfiguration(
      baseURL: URL(string: "https://api.example.com")!,
      retryPolicy: NoRetryPolicy()
    )

    #expect(config.retryPolicy.maxRetries == 0)
  }
}
