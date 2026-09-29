// DebugLogLevel.swift
// DropClip
//
// Severity level of a captured debug log entry.
// Bridges to DropClipCore.LogLevel and provides OSLog compatibility initializer for tests.

import OSLog
import DropClipCore

public typealias DebugLogLevel = LogLevel

extension LogLevel {
    public init(_ level: OSLogEntryLog.Level) {
        switch level {
        case .undefined: self = .debug
        case .debug: self = .debug
        case .info: self = .info
        case .notice: self = .notice
        case .error: self = .error
        case .fault: self = .fault
        @unknown default: self = .debug
        }
    }
}
