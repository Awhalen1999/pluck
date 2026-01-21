//
//  DataModels.swift
//  Pluck
//
//  SwiftData models with validation, computed properties, and safety guards.
//

import Foundation
import SwiftData

// MARK: - Constants

enum DesignConstants {
    static let defaultFolderColor = "#6366F1"
    static let maxFolderNameLength = 100
    static let maxImageNameLength = 200
}

// MARK: - DesignFolder

@Model
final class DesignFolder {
    
    // MARK: - Stored Properties
    
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \DesignImage.folder)
    var images: [DesignImage] = []
    
    // MARK: - Initialization
    
    init(
        name: String,
        colorHex: String = DesignConstants.defaultFolderColor,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = Self.sanitizeName(name)
        self.colorHex = Self.sanitizeColorHex(colorHex)
        self.sortOrder = max(0, sortOrder)
        self.createdAt = Date()
        
        Log.debug("DesignFolder created: '\(self.name)' (id: \(self.id.uuidString.prefix(8)))", subsystem: .data)
    }
    
    // MARK: - Computed Properties
    
    var imageCount: Int { images.count }
    
    var sortedImages: [DesignImage] {
        images.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    var isEmpty: Bool { images.isEmpty }
    
    var mostRecentImage: DesignImage? {
        images.max { $0.createdAt < $1.createdAt }
    }
    
    // MARK: - Validation & Sanitization
    
    static func sanitizeName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = String(trimmed.prefix(DesignConstants.maxFolderNameLength))
        return limited.isEmpty ? "Untitled Folder" : limited
    }
    
    static func sanitizeColorHex(_ hex: String) -> String {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure it starts with #
        if !sanitized.hasPrefix("#") {
            sanitized = "#" + sanitized
        }
        
        // Validate hex format (# + 6 hex chars)
        let hexPattern = "^#[0-9A-Fa-f]{6}$"
        guard sanitized.range(of: hexPattern, options: .regularExpression) != nil else {
            Log.warning("Invalid color hex '\(hex)', using default", subsystem: .data)
            return DesignConstants.defaultFolderColor
        }
        
        return sanitized.uppercased()
    }
    
    // MARK: - Mutators
    
    func updateName(_ newName: String) {
        let sanitized = Self.sanitizeName(newName)
        guard sanitized != name else { return }
        name = sanitized
        Log.debug("Folder renamed to '\(name)'", subsystem: .data)
    }
    
    func updateColor(_ newColorHex: String) {
        let sanitized = Self.sanitizeColorHex(newColorHex)
        guard sanitized != colorHex else { return }
        colorHex = sanitized
    }
    
    func nextImageSortOrder() -> Int {
        (images.map(\.sortOrder).max() ?? -1) + 1
    }
}

// MARK: - DesignImage

@Model
final class DesignImage {
    
    // MARK: - Stored Properties
    
    @Attribute(.unique) var id: UUID
    var filename: String
    var originalName: String
    var sourceURL: String?
    var sortOrder: Int
    var createdAt: Date
    var folder: DesignFolder?
    
    // MARK: - Initialization
    
    init(
        filename: String,
        originalName: String,
        sourceURL: String? = nil,
        sortOrder: Int = 0,
        folder: DesignFolder? = nil
    ) {
        self.id = UUID()
        self.filename = Self.sanitizeFilename(filename)
        self.originalName = Self.sanitizeOriginalName(originalName)
        self.sourceURL = sourceURL
        self.sortOrder = max(0, sortOrder)
        self.createdAt = Date()
        self.folder = folder
        
        Log.debug("DesignImage created: '\(self.originalName)' → \(self.filename)", subsystem: .data)
    }
    
    // MARK: - Computed Properties
    
    var fileExtension: String {
        (filename as NSString).pathExtension.lowercased()
    }
    
    var isSVG: Bool {
        fileExtension == "svg"
    }
    
    var displayName: String {
        originalName.isEmpty ? filename : originalName
    }
    
    // MARK: - Validation & Sanitization
    
    static func sanitizeFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove any path components for security
        let lastComponent = (trimmed as NSString).lastPathComponent
        
        guard !lastComponent.isEmpty else {
            Log.error("Empty filename provided, generating fallback", subsystem: .data)
            return "\(UUID().uuidString).png"
        }
        
        return lastComponent
    }
    
    static func sanitizeOriginalName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(DesignConstants.maxImageNameLength))
    }
    
    // MARK: - Mutators
    
    func updateOriginalName(_ newName: String) {
        let sanitized = Self.sanitizeOriginalName(newName)
        guard !sanitized.isEmpty, sanitized != originalName else { return }
        originalName = sanitized
        Log.debug("Image renamed to '\(originalName)'", subsystem: .data)
    }
}
