//
//  FileManagerHelper.swift
//  Pluck
//

import Foundation
import AppKit

struct FileManagerHelper {
    
    static var appSupportDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appFolder = paths[0].appendingPathComponent("Pluck")
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
    
    // MARK: - Save Image
    
    static func saveImage(_ imageData: Data, originalName: String) -> String? {
        let filename = UUID().uuidString + ".png"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: fileURL)
            generateThumbnail(from: fileURL, filename: filename)
            return filename
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
    
    // MARK: - Thumbnail Generation
    
    private static func generateThumbnail(from imageURL: URL, filename: String) {
        guard let image = NSImage(contentsOf: imageURL) else { return }
        
        let thumbnailSize = NSSize(width: 200, height: 200)
        let aspectRatio = image.size.width / image.size.height
        
        var newSize: NSSize
        if aspectRatio > 1 {
            newSize = NSSize(width: thumbnailSize.width, height: thumbnailSize.width / aspectRatio)
        } else {
            newSize = NSSize(width: thumbnailSize.height * aspectRatio, height: thumbnailSize.height)
        }
        
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()
        
        if let tiffData = thumbnail.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            let thumbnailURL = thumbnailsDirectory.appendingPathComponent(filename)
            try? pngData.write(to: thumbnailURL)
        }
    }
    
    // MARK: - Load Images
    
    static func loadImage(filename: String) -> NSImage? {
        let url = imagesDirectory.appendingPathComponent(filename)
        return NSImage(contentsOf: url)
    }
    
    static func loadThumbnail(filename: String) -> NSImage? {
        let url = thumbnailsDirectory.appendingPathComponent(filename)
        return NSImage(contentsOf: url)
    }
    
    // MARK: - Delete Image
    
    static func deleteImage(filename: String) {
        let imageURL = imagesDirectory.appendingPathComponent(filename)
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(filename)
        
        try? FileManager.default.removeItem(at: imageURL)
        try? FileManager.default.removeItem(at: thumbnailURL)
    }
}
