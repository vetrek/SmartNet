//
//  ThreadSafe.swift
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

import os

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
  private let lock = OSAllocatedUnfairLock()

  /// Initializes the property with a value.
  /// - Parameter wrappedValue: The initial value of the property.
  public init(wrappedValue: Value) {
    self.value = wrappedValue
  }

  /// The property's value. Access to this value is synchronized.
  public var wrappedValue: Value {
    get { lock.withLockUnchecked { value } }
    set { lock.withLockUnchecked { value = newValue } }
    _modify {
      lock.lock()
      defer { lock.unlock() }
      yield &value
    }
  }

  public subscript<Property>(dynamicMember keyPath: WritableKeyPath<Value, Property>) -> Property {
    get { lock.withLockUnchecked { value[keyPath: keyPath] } }
    set { lock.withLockUnchecked { value[keyPath: keyPath] = newValue } }
    _modify {
      lock.lock()
      defer { lock.unlock() }
      yield &value[keyPath: keyPath]
    }
  }

  public subscript<Property>(dynamicMember keyPath: KeyPath<Value, Property>) -> Property {
    lock.withLockUnchecked { value[keyPath: keyPath] }
  }
}
