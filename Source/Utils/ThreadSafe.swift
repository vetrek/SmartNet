//
//  ApiClient.swift
//
//  Adapted from CwlUtils by Matt Gallagher.
//  Original source: https://github.com/mattgallagher/CwlUtils/blob/master/Sources/CwlUtils/CwlMutex.swift
//
//  Copyright (c) 2021 Valerio (valerio.alsebas@gmail.com)
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

#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// A basic mutex protocol that requires nothing more than "performing work inside the mutex".
public protocol ScopedMutex {
  /// Perform work inside the mutex
  func sync<R>(execute work: () throws -> R) rethrows -> R
  
  /// Perform work inside the mutex, returning immediately if the mutex is in-use
  func trySync<R>(execute work: () throws -> R) rethrows -> R?
}

/// A more specific kind of mutex that assume an underlying primitive and unbalanced lock/trylock/unlock operators
public protocol RawMutex: ScopedMutex {
  associatedtype MutexPrimitive
  
  var underlyingMutex: MutexPrimitive { get set }
  
  func unbalancedLock()
  func unbalancedTryLock() -> Bool
  func unbalancedUnlock()
}

public extension RawMutex {
  func sync<R>(execute work: () throws -> R) rethrows -> R {
    unbalancedLock()
    defer { unbalancedUnlock() }
    return try work()
  }
  func trySync<R>(execute work: () throws -> R) rethrows -> R? {
    guard unbalancedTryLock() else { return nil }
    defer { unbalancedUnlock() }
    return try work()
  }
}

/// A basic wrapper around the "NORMAL" and "RECURSIVE" `pthread_mutex_t` (a general purpose mutex). This type is a "class" type to take advantage of the "deinit" method and prevent accidental copying of the `pthread_mutex_t`.
public final class PThreadMutex: RawMutex {
  public typealias MutexPrimitive = pthread_mutex_t
  
  // Non-recursive "PTHREAD_MUTEX_NORMAL" and recursive "PTHREAD_MUTEX_RECURSIVE" mutex types.
  public enum PThreadMutexType {
    case normal
    case recursive
  }
  
  public var underlyingMutex = pthread_mutex_t()
  
  /// Default constructs as ".Normal" or ".Recursive" on request.
  public init(type: PThreadMutexType = .normal) {
    var attr = pthread_mutexattr_t()
    guard pthread_mutexattr_init(&attr) == 0 else {
      preconditionFailure()
    }
    switch type {
    case .normal:
      pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL)
    case .recursive:
      pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)
    }
    guard pthread_mutex_init(&underlyingMutex, &attr) == 0 else {
      preconditionFailure()
    }
    pthread_mutexattr_destroy(&attr)
  }
  
  public func unbalancedLock() {
    pthread_mutex_lock(&underlyingMutex)
  }
  
  public func unbalancedTryLock() -> Bool {
    return pthread_mutex_trylock(&underlyingMutex) == 0
  }
  
  public func unbalancedUnlock() {
    pthread_mutex_unlock(&underlyingMutex)
  }
  
  deinit {
    pthread_mutex_destroy(&underlyingMutex)
  }
}

/// A basic wrapper around `os_unfair_lock` (a non-FIFO, high performance lock that offers safety against priority inversion). This type is a "class" type to prevent accidental copying of the `os_unfair_lock`.
@available(OSX 10.12, iOS 10, tvOS 10, watchOS 3, *)
public final class UnfairLock: RawMutex {
  public typealias MutexPrimitive = os_unfair_lock
  
  public init() {
  }
  
  /// Exposed as an "unsafe" property so non-scoped patterns can be implemented, if required.
  public var underlyingMutex = os_unfair_lock()
  
  public func unbalancedLock() {
    os_unfair_lock_lock(&underlyingMutex)
  }
  
  public func unbalancedTryLock() -> Bool {
    return os_unfair_lock_trylock(&underlyingMutex)
  }
  
  public func unbalancedUnlock() {
    os_unfair_lock_unlock(&underlyingMutex)
  }
}

/// Property wrapper that ensures thread-safe access to its value.
///
/// This is implemented as a class (not struct) to ensure thread safety when used on class properties.
/// A struct property wrapper would have its storage embedded in the containing class, leading to
/// race conditions when multiple threads access the property simultaneously - even with internal
/// mutex protection, the struct copy-on-write semantics create a data race at the storage level.
/// Using a class ensures all mutations happen inside the reference type, protected by the mutex.
@propertyWrapper
@dynamicMemberLookup
public final class ThreadSafe<Value> {
  private var value: Value
  private let mutex: any ScopedMutex

  /// Initializes the property with a value and a mutex.
  /// - Parameters:
  ///   - wrappedValue: The initial value of the property.
  ///   - mutex: An object conforming to `ScopedMutex` to be used for synchronization.
  public init(wrappedValue: Value, mutex: any ScopedMutex = PThreadMutex()) {
    self.value = wrappedValue
    self.mutex = mutex
  }

  /// The property's value. Access to this value is synchronized.
  public var wrappedValue: Value {
    get { mutex.sync { value } }
    set { mutex.sync { value = newValue } }
  }

  public subscript<Property>(dynamicMember keyPath: WritableKeyPath<Value, Property>) -> Property {
    get { mutex.sync { value[keyPath: keyPath] } }
    set { mutex.sync { value[keyPath: keyPath] = newValue } }
  }

  public subscript<Property>(dynamicMember keyPath: KeyPath<Value, Property>) -> Property {
    mutex.sync { value[keyPath: keyPath] }
  }
}
