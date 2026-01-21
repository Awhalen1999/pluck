//
//  Logger.swift
//  Pluck
//
//  Thread-safe, structured logging with subsystems and levels.
//  Production-ready with compile-time stripping of debug logs.
//

import Foundation
import os.log

// MARK: - Log Level

enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

// MARK: - Log Subsystem

enum LogSubsystem: String {
    case app = "App"
    case window = "Window"
    case data = "Data"
    case file = "File"
    case clipboard = "Clipboard"
    case ui = "UI"
    case drop = "Drop"
    
    var osLog: OSLog {
        OSLog(subsystem: "com.pluck.app", category: rawValue)
    }
}

// MARK: - Logger

enum Log {
    
    // MARK: - Configuration
    
    #if DEBUG
    private static let minimumLevel: LogLevel = .debug
    private static let isEnabled = true
    #else
    private static let minimumLevel: LogLevel = .warning
    private static let isEnabled = true
    #endif
    
    // MARK: - Thread-Safe Queue
    
    private static let queue = DispatchQueue(label: "com.pluck.logger", qos: .utility)
    
    // MARK: - Core Logging
    
    private static func log(
        _ level: LogLevel,
        subsystem: LogSubsystem,
        message: @autoclosure () -> String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled, level >= minimumLevel else { return }
        
        let messageString = message()
        let fileName = (file as NSString).lastPathComponent
        
        queue.async {
            var output = "\(level.emoji) [\(subsystem.rawValue)] \(messageString)"
            
            if let error = error {
                output += " | Error: \(error.localizedDescription)"
            }
            
            #if DEBUG
            output += " | \(fileName):\(line)"
            #endif
            
            // Console output
            print(output)
            
            // System log
            os_log("%{public}@", log: subsystem.osLog, type: level.osLogType, output)
        }
    }
    
    // MARK: - Convenience Methods
    
    static func debug(_ message: @autoclosure () -> String, subsystem: LogSubsystem = .app, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(.debug, subsystem: subsystem, message: message(), file: file, function: function, line: line)
        #endif
    }
    
    static func info(_ message: @autoclosure () -> String, subsystem: LogSubsystem = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, subsystem: subsystem, message: message(), file: file, function: function, line: line)
    }
    
    static func warning(_ message: @autoclosure () -> String, subsystem: LogSubsystem = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, subsystem: subsystem, message: message(), file: file, function: function, line: line)
    }
    
    static func error(_ message: @autoclosure () -> String, error: Error? = nil, subsystem: LogSubsystem = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, subsystem: subsystem, message: message(), error: error, file: file, function: function, line: line)
    }
    
    static func critical(_ message: @autoclosure () -> String, error: Error? = nil, subsystem: LogSubsystem = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(.critical, subsystem: subsystem, message: message(), error: error, file: file, function: function, line: line)
    }
    
    // MARK: - Scoped Logging
    
    static func scope(_ name: String, subsystem: LogSubsystem = .app, _ block: () throws -> Void) rethrows {
        let start = CFAbsoluteTimeGetCurrent()
        debug("→ \(name) started", subsystem: subsystem)
        
        defer {
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
            debug("← \(name) completed in \(String(format: "%.2f", duration))ms", subsystem: subsystem)
        }
        
        try block()
    }
    
    static func scope<T>(_ name: String, subsystem: LogSubsystem = .app, _ block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        debug("→ \(name) started", subsystem: subsystem)
        
        defer {
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
            debug("← \(name) completed in \(String(format: "%.2f", duration))ms", subsystem: subsystem)
        }
        
        return try block()
    }
}

// MARK: - Legacy Compatibility (deprecated)

@available(*, deprecated, renamed: "Log")
enum Logger {
    static func error(_ message: String, error: Error? = nil) {
        Log.error(message, error: error)
    }
    
    static func warning(_ message: String) {
        Log.warning(message)
    }
    
    static func info(_ message: String) {
        Log.info(message)
    }
}
