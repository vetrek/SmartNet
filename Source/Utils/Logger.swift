//
//  Logger.swift
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
import os.log

/// Log levels for SmartNet logging
public enum LogLevel: Int, Comparable {
  case debug = 0
  case info = 1
  case warning = 2
  case error = 3
  case none = 4

  public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  var osLogType: OSLogType {
    switch self {
    case .debug: return .debug
    case .info: return .info
    case .warning: return .default
    case .error: return .error
    case .none: return .debug
    }
  }
}

/// Internal logger for SmartNet using os_log
public final class SmartNetLogger {
  /// Shared instance
  public static let shared = SmartNetLogger()

  /// The minimum log level to output (default: .warning in release, .debug in debug)
  public var minimumLogLevel: LogLevel

  /// Enable/disable logging entirely
  public var isEnabled: Bool = true

  private let log: OSLog

  private init() {
    self.log = OSLog(subsystem: "com.smartnet", category: "network")
    #if DEBUG
    self.minimumLogLevel = .debug
    #else
    self.minimumLogLevel = .warning
    #endif
  }

  /// Log a debug message
  public func debug(_ message: @autoclosure () -> String) {
    log(message(), level: .debug)
  }

  /// Log an info message
  public func info(_ message: @autoclosure () -> String) {
    log(message(), level: .info)
  }

  /// Log a warning message
  public func warning(_ message: @autoclosure () -> String) {
    log(message(), level: .warning)
  }

  /// Log an error message
  public func error(_ message: @autoclosure () -> String) {
    log(message(), level: .error)
  }

  /// Log a message at the specified level
  public func log(_ message: @autoclosure () -> String, level: LogLevel) {
    guard isEnabled, level >= minimumLogLevel, level != .none else { return }
    os_log("%{public}@", log: log, type: level.osLogType, message())
  }
}
