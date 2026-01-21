//
//  Color+Hex.swift
//  Pluck
//
//  Color extension for hex string conversion with validation.
//

import SwiftUI
import AppKit

// MARK: - Hex Initialization

extension Color {
    
    /// Initialize a Color from a hex string (e.g., "#FF6B6B" or "FF6B6B")
    init?(hex: String) {
        let sanitized = Self.sanitizeHexString(hex)
        
        guard let rgb = Self.parseHexToRGB(sanitized) else {
            return nil
        }
        
        self.init(
            red: Double(rgb.r) / 255.0,
            green: Double(rgb.g) / 255.0,
            blue: Double(rgb.b) / 255.0
        )
    }
    
    /// Sanitize hex string by removing whitespace and # prefix
    private static func sanitizeHexString(_ hex: String) -> String {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if sanitized.hasPrefix("#") {
            sanitized.removeFirst()
        }
        
        return sanitized.uppercased()
    }
    
    /// Parse hex string to RGB components
    private static func parseHexToRGB(_ hex: String) -> (r: Int, g: Int, b: Int)? {
        guard hex.count == 6 else { return nil }
        
        var rgb: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgb) else { return nil }
        
        return (
            r: Int((rgb & 0xFF0000) >> 16),
            g: Int((rgb & 0x00FF00) >> 8),
            b: Int(rgb & 0x0000FF)
        )
    }
}

// MARK: - Hex String Output

extension Color {
    
    /// Convert color to hex string (e.g., "#FF6B6B")
    var hexString: String {
        // Convert to NSColor first, then get components
        let nsColor = NSColor(self)
        
        // Try to convert to RGB color space
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            return "#000000"
        }
        
        let r = Int((rgbColor.redComponent * 255).rounded())
        let g = Int((rgbColor.greenComponent * 255).rounded())
        let b = Int((rgbColor.blueComponent * 255).rounded())
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Preset Colors

extension Color {
    enum Pluck {
        static let folderColors: [String] = [
            "#8B5CF6", // Purple
            "#3B82F6", // Blue
            "#10B981", // Green
            "#F59E0B", // Amber
            "#EF4444", // Red
            "#EC4899", // Pink
            "#6366F1", // Indigo
            "#14B8A6", // Teal
        ]
        
        static let defaultFolderColor = "#6366F1"
    }
}
