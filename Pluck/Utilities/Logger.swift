//
//  Logger.swift
//  Pluck
//

import Foundation

enum Logger {
    static func error(_ message: String, error: Error? = nil) {
        #if DEBUG
        if let error = error {
            print("❌ [Pluck] \(message): \(error.localizedDescription)")
        } else {
            print("❌ [Pluck] \(message)")
        }
        #endif
    }
    
    static func warning(_ message: String) {
        #if DEBUG
        print("⚠️ [Pluck] \(message)")
        #endif
    }
    
    static func info(_ message: String) {
        #if DEBUG
        print("ℹ️ [Pluck] \(message)")
        #endif
    }
}
