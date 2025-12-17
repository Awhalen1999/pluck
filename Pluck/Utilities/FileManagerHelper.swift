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
    
    // MARK: - Supported Formats
    
    static let supportedImageExtensions = Set(["png", "jpg", "jpeg", "gif", "webp", "tiff", "bmp", "heic", "svg"])
    
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
        // Thumbnails are always PNG, even for SVGs
        let baseName = (filename as NSString).deletingPathExtension
        return thumbnailsDirectory.appendingPathComponent(baseName + ".png")
    }
    
    static func isSVG(filename: String) -> Bool {
        filename.lowercased().hasSuffix(".svg")
    }
    
    // MARK: - Save Image
    
    enum SaveError: Error {
        case writeFailed(Error)
        case thumbnailGenerationFailed
        case unsupportedFormat
    }
    
    /// Save image data with automatic format detection
    static func saveImage(_ imageData: Data, originalName: String, fileExtension: String? = nil) throws -> String {
        // Determine the file extension
        let ext = fileExtension?.lowercased() ?? detectImageFormat(from: imageData) ?? "png"
        let filename = UUID().uuidString + "." + ext
        let fileURL = imageURL(for: filename)
        
        do {
            try imageData.write(to: fileURL)
        } catch {
            throw SaveError.writeFailed(error)
        }
        
        generateThumbnail(from: fileURL, filename: filename)
        return filename
    }
    
    /// Save image from a file URL (preserves original format)
    static func saveImageFromURL(_ sourceURL: URL, originalName: String) throws -> String {
        let ext = sourceURL.pathExtension.lowercased()
        guard supportedImageExtensions.contains(ext) else {
            throw SaveError.unsupportedFormat
        }
        
        let filename = UUID().uuidString + "." + ext
        let destURL = imageURL(for: filename)
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        } catch {
            throw SaveError.writeFailed(error)
        }
        
        generateThumbnail(from: destURL, filename: filename)
        return filename
    }
    
    /// Detect image format from data
    private static func detectImageFormat(from data: Data) -> String? {
        guard data.count >= 12 else { return nil }
        
        let bytes = [UInt8](data.prefix(12))
        
        // PNG: 89 50 4E 47
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "png"
        }
        
        // JPEG: FF D8 FF
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "jpg"
        }
        
        // GIF: 47 49 46 38
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 {
            return "gif"
        }
        
        // WebP: RIFF....WEBP
        if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
           bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50 {
            return "webp"
        }
        
        // SVG: Check for XML/SVG markers (text-based)
        if let str = String(data: data.prefix(1000), encoding: .utf8) {
            if str.contains("<svg") || str.contains("<?xml") && str.contains("svg") {
                return "svg"
            }
        }
        
        // TIFF: 49 49 2A 00 or 4D 4D 00 2A
        if (bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) ||
           (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A) {
            return "tiff"
        }
        
        return nil
    }
    
    // MARK: - Load Images
    
    static func loadImage(filename: String) -> NSImage? {
        let url = imageURL(for: filename)
        
        if isSVG(filename: filename) {
            return loadSVGImage(from: url)
        }
        
        return NSImage(contentsOf: url)
    }
    
    static func loadThumbnail(filename: String) -> NSImage? {
        NSImage(contentsOf: thumbnailURL(for: filename))
    }
    
    /// Load SVG with proper rendering
    private static func loadSVGImage(from url: URL) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        
        // NSImage can load SVGs, but we may need to ensure it renders at a good size
        // If the image has no size, set a reasonable default
        if image.size.width == 0 || image.size.height == 0 {
            image.size = NSSize(width: 512, height: 512)
        }
        
        return image
    }
    
    // MARK: - Delete Image
    
    static func deleteImage(filename: String) {
        try? FileManager.default.removeItem(at: imageURL(for: filename))
        try? FileManager.default.removeItem(at: thumbnailURL(for: filename))
    }
    
    // MARK: - Thumbnail Generation
    
    private static func generateThumbnail(from imageURL: URL, filename: String) {
        let maxDimension = Config.thumbnailSize
        
        // For SVGs, render directly at target size for best quality
        if isSVG(filename: filename) {
            guard let thumbnail = renderSVGThumbnail(from: imageURL, maxSize: maxDimension),
                  let pngData = thumbnail.pngData else { return }
            try? pngData.write(to: thumbnailURL(for: filename))
            return
        }
        
        // For raster images, scale down normally
        guard let image = NSImage(contentsOf: imageURL) else { return }
        
        var size = image.size
        if size.width == 0 || size.height == 0 { return }
        
        let aspectRatio = size.width / size.height
        
        let newSize: NSSize
        if aspectRatio > 1 {
            newSize = NSSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = NSSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        guard let thumbnail = renderImageToSize(image, size: newSize),
              let pngData = thumbnail.pngData else { return }
        
        try? pngData.write(to: thumbnailURL(for: filename))
    }
    
    /// Render SVG at target size for crisp thumbnails
    private static func renderSVGThumbnail(from url: URL, maxSize: CGFloat) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        
        var size = image.size
        
        // SVGs can report 0 size - try to get a reasonable default
        if size.width <= 0 || size.height <= 0 {
            size = NSSize(width: 100, height: 100)
        }
        
        let aspectRatio = size.width / size.height
        
        let targetSize: NSSize
        if aspectRatio > 1 {
            targetSize = NSSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            targetSize = NSSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        // Create a bitmap context at exactly the target size
        // This lets the SVG render at the right resolution instead of scaling
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetSize.width * 2), // 2x for retina
            pixelsHigh: Int(targetSize.height * 2),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        
        bitmapRep.size = targetSize // Points, not pixels
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.current?.imageInterpolation = .high
        NSGraphicsContext.current?.shouldAntialias = true
        
        // Draw the SVG - it will render vectors at the bitmap's resolution
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        
        NSGraphicsContext.restoreGraphicsState()
        
        let result = NSImage(size: targetSize)
        result.addRepresentation(bitmapRep)
        return result
    }
    
    /// Render a raster image to a specific size
    private static func renderImageToSize(_ image: NSImage, size: NSSize) -> NSImage? {
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * 2),
            pixelsHigh: Int(size.height * 2),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        
        bitmapRep.size = size
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.current?.imageInterpolation = .high
        NSGraphicsContext.current?.shouldAntialias = true
        
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        
        NSGraphicsContext.restoreGraphicsState()
        
        let result = NSImage(size: size)
        result.addRepresentation(bitmapRep)
        return result
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
