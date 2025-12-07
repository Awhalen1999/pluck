//
//  DataModels.swift
//  Pluck
//

import Foundation
import SwiftData

// MARK: - Constants

enum DesignConstants {
    static let defaultFolderColor = "#6366F1"
}

// MARK: - DesignFolder

@Model
class DesignFolder {
    var id: UUID
    var name: String
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \DesignImage.folder)
    var images: [DesignImage] = []
    
    init(
        name: String,
        colorHex: String = DesignConstants.defaultFolderColor,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
    
    var imageCount: Int { images.count }
    
    var sortedImages: [DesignImage] {
        images.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - DesignImage

@Model
class DesignImage {
    var id: UUID
    var filename: String
    var originalName: String
    var sourceURL: String?
    var sortOrder: Int
    var createdAt: Date
    var folder: DesignFolder?
    
    init(
        filename: String,
        originalName: String,
        sourceURL: String? = nil,
        sortOrder: Int = 0,
        folder: DesignFolder? = nil
    ) {
        self.id = UUID()
        self.filename = filename
        self.originalName = originalName
        self.sourceURL = sourceURL
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.folder = folder
    }
}
