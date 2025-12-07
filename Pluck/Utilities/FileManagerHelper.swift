//
//  FileManagerHelper.swift
//  Pluck
//

import Foundation
import AppKit

enum FileManagerHelper {
    
    // MARK: - Configuration
    
    private enum Config {
        static let thumbnailSize: CGFloat = 200
        static let appFolderName = "Pluck"
    }
    
    // MARK: - Directories
    
    static var appSupportDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appFolder = paths[0].appendingPathComponent(Config.appFolderName)
        ensureDirectoryExists(appFolder)
        return appFolder
    }
    
    static var imagesDirectory: URL {
        let dir = appSupportDirectory.appendingPathComponent("images")
        ensureDirectoryExists(dir)
        return dir
    }
    
    static var thumbnailsDirectory: URL {
        let dir = appSupportDirectory.appendingPathComponent("thumbnails")
        ensureDirectoryExists(dir)
        return dir
    }
    
    private static func ensureDirectoryExists(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    // MARK: - URL Helpers
    
    static func imageURL(for filename: String) -> URL {
        imagesDirectory.appendingPathComponent(filename)
    }
    
    static func thumbnailURL(for filename: String) -> URL {
        thumbnailsDirectory.appendingPathComponent(filename)
    }
    
    // MARK: - Save Image
    
    enum SaveError: Error {
        case writeFailed(Error)
        case thumbnailGenerationFailed
    }
    
    static func saveImage(_ imageData: Data, originalName: String) throws -> String {
        let filename = UUID().uuidString + ".png"
        let fileURL = imageURL(for: filename)
        
        do {
            try imageData.write(to: fileURL)
        } catch {
            throw SaveError.writeFailed(error)
        }
        
        generateThumbnail(from: fileURL, filename: filename)
        return filename
    }
    
    // MARK: - Load Images
    
    static func loadImage(filename: String) -> NSImage? {
        NSImage(contentsOf: imageURL(for: filename))
    }
    
    static func loadThumbnail(filename: String) -> NSImage? {
        NSImage(contentsOf: thumbnailURL(for: filename))
    }
    
    // MARK: - Delete Image
    
    static func deleteImage(filename: String) {
        try? FileManager.default.removeItem(at: imageURL(for: filename))
        try? FileManager.default.removeItem(at: thumbnailURL(for: filename))
    }
    
    // MARK: - Thumbnail Generation
    
    private static func generateThumbnail(from imageURL: URL, filename: String) {
        guard let image = NSImage(contentsOf: imageURL) else { return }
        
        let maxDimension = Config.thumbnailSize
        let aspectRatio = image.size.width / image.size.height
        
        let newSize: NSSize
        if aspectRatio > 1 {
            newSize = NSSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = NSSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        guard let thumbnail = resizedImage(image, to: newSize),
              let pngData = thumbnail.pngData else { return }
        
        try? pngData.write(to: thumbnailURL(for: filename))
    }
    
    private static func resizedImage(_ image: NSImage, to size: NSSize) -> NSImage? {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }
}

// MARK: - NSImage Extension

private extension NSImage {
    var pngData: Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
