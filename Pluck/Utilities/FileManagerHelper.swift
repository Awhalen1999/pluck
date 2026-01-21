//
//  FileManagerHelper.swift
//  Pluck
//
//  File operations with comprehensive error handling, validation,
//  and thread-safe operations. Production-ready file management.
//

import Foundation
import AppKit

// MARK: - File Manager Errors

enum FileManagerError: LocalizedError {
    case directoryCreationFailed(URL, Error)
    case writeFailed(URL, Error)
    case readFailed(URL, Error)
    case copyFailed(source: URL, destination: URL, Error)
    case deleteFailed(URL, Error)
    case unsupportedFormat(String)
    case invalidData
    case thumbnailGenerationFailed(String)
    case fileTooLarge(size: Int64, maxSize: Int64)
    case fileNotFound(URL)
    
    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let url, let error):
            return "Failed to create directory at \(url.path): \(error.localizedDescription)"
        case .writeFailed(let url, let error):
            return "Failed to write file at \(url.path): \(error.localizedDescription)"
        case .readFailed(let url, let error):
            return "Failed to read file at \(url.path): \(error.localizedDescription)"
        case .copyFailed(let source, let destination, let error):
            return "Failed to copy from \(source.path) to \(destination.path): \(error.localizedDescription)"
        case .deleteFailed(let url, let error):
            return "Failed to delete file at \(url.path): \(error.localizedDescription)"
        case .unsupportedFormat(let ext):
            return "Unsupported image format: \(ext)"
        case .invalidData:
            return "Invalid or corrupted image data"
        case .thumbnailGenerationFailed(let filename):
            return "Failed to generate thumbnail for \(filename)"
        case .fileTooLarge(let size, let maxSize):
            return "File too large: \(size) bytes (max: \(maxSize) bytes)"
        case .fileNotFound(let url):
            return "File not found: \(url.path)"
        }
    }
}

// MARK: - File Manager Helper

enum FileManagerHelper {
    
    // MARK: - Configuration
    
    private enum Config {
        static let appFolderName = "Pluck"
        static let imagesFolderName = "images"
        static let thumbnailsFolderName = "thumbnails"
        static let thumbnailSize: CGFloat = 200
        static let maxFileSizeBytes: Int64 = 100 * 1024 * 1024  // 100MB
        static let retinaScale: CGFloat = 2.0
    }
    
    // MARK: - Supported Formats
    
    static let supportedImageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "tiff", "bmp", "heic", "svg"
    ]
    
    private static let imageSignatures: [(bytes: [UInt8], extension: String)] = [
        ([0x89, 0x50, 0x4E, 0x47], "png"),                     // PNG
        ([0xFF, 0xD8, 0xFF], "jpg"),                           // JPEG
        ([0x47, 0x49, 0x46, 0x38], "gif"),                     // GIF
        ([0x52, 0x49, 0x46, 0x46], "webp"),                    // WebP (RIFF header)
        ([0x49, 0x49, 0x2A, 0x00], "tiff"),                    // TIFF (little endian)
        ([0x4D, 0x4D, 0x00, 0x2A], "tiff"),                    // TIFF (big endian)
    ]
    
    // MARK: - Directories
    
    private static let fileManager = FileManager.default
    
    static var appSupportDirectory: URL {
        get throws {
            let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            guard let basePath = paths.first else {
                throw FileManagerError.directoryCreationFailed(
                    URL(fileURLWithPath: "~/Library/Application Support"),
                    NSError(domain: "FileManagerHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "No application support directory found"])
                )
            }
            let appFolder = basePath.appendingPathComponent(Config.appFolderName)
            try ensureDirectoryExists(appFolder)
            return appFolder
        }
    }
    
    static var imagesDirectory: URL {
        get throws {
            let dir = try appSupportDirectory.appendingPathComponent(Config.imagesFolderName)
            try ensureDirectoryExists(dir)
            return dir
        }
    }
    
    static var thumbnailsDirectory: URL {
        get throws {
            let dir = try appSupportDirectory.appendingPathComponent(Config.thumbnailsFolderName)
            try ensureDirectoryExists(dir)
            return dir
        }
    }
    
    private static func ensureDirectoryExists(_ url: URL) throws {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            Log.debug("Created directory: \(url.path)", subsystem: .file)
        } catch {
            Log.error("Failed to create directory: \(url.path)", error: error, subsystem: .file)
            throw FileManagerError.directoryCreationFailed(url, error)
        }
    }
    
    // MARK: - URL Helpers
    
    static func imageURL(for filename: String) -> URL? {
        guard !filename.isEmpty else {
            Log.warning("Empty filename requested", subsystem: .file)
            return nil
        }
        do {
            return try imagesDirectory.appendingPathComponent(filename)
        } catch {
            Log.error("Failed to get images directory", error: error, subsystem: .file)
            return nil
        }
    }
    
    static func thumbnailURL(for filename: String) -> URL? {
        guard !filename.isEmpty else { return nil }
        do {
            let baseName = (filename as NSString).deletingPathExtension
            return try thumbnailsDirectory.appendingPathComponent(baseName + ".png")
        } catch {
            Log.error("Failed to get thumbnails directory", error: error, subsystem: .file)
            return nil
        }
    }
    
    static func isSVG(filename: String) -> Bool {
        filename.lowercased().hasSuffix(".svg")
    }
    
    static func isSupported(extension ext: String) -> Bool {
        supportedImageExtensions.contains(ext.lowercased())
    }
    
    // MARK: - Save Image from Data
    
    static func saveImage(_ imageData: Data, originalName: String, fileExtension: String? = nil) throws -> String {
        guard !imageData.isEmpty else {
            Log.error("Empty image data provided", subsystem: .file)
            throw FileManagerError.invalidData
        }
        
        // Validate file size
        let dataSize = Int64(imageData.count)
        guard dataSize <= Config.maxFileSizeBytes else {
            Log.error("File too large: \(dataSize) bytes", subsystem: .file)
            throw FileManagerError.fileTooLarge(size: dataSize, maxSize: Config.maxFileSizeBytes)
        }
        
        // Determine file extension
        let ext: String
        if let provided = fileExtension?.lowercased(), isSupported(extension: provided) {
            ext = provided
        } else if let detected = detectImageFormat(from: imageData) {
            ext = detected
        } else {
            ext = "png"  // Fallback
        }
        
        let filename = UUID().uuidString + "." + ext
        
        guard let fileURL = imageURL(for: filename) else {
            throw FileManagerError.invalidData
        }
        
        do {
            try imageData.write(to: fileURL, options: .atomic)
            Log.info("Saved image: \(filename) (\(dataSize) bytes)", subsystem: .file)
        } catch {
            Log.error("Failed to write image", error: error, subsystem: .file)
            throw FileManagerError.writeFailed(fileURL, error)
        }
        
        // Generate thumbnail asynchronously (don't fail the save)
        Task.detached(priority: .utility) {
            await generateThumbnailAsync(from: fileURL, filename: filename)
        }
        
        return filename
    }
    
    // MARK: - Save Image from URL
    
    static func saveImageFromURL(_ sourceURL: URL, originalName: String) throws -> String {
        let ext = sourceURL.pathExtension.lowercased()
        
        guard isSupported(extension: ext) else {
            Log.error("Unsupported format: \(ext)", subsystem: .file)
            throw FileManagerError.unsupportedFormat(ext)
        }
        
        // Verify source exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            Log.error("Source file not found: \(sourceURL.path)", subsystem: .file)
            throw FileManagerError.fileNotFound(sourceURL)
        }
        
        // Check file size
        do {
            let attributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
            if let fileSize = attributes[.size] as? Int64, fileSize > Config.maxFileSizeBytes {
                throw FileManagerError.fileTooLarge(size: fileSize, maxSize: Config.maxFileSizeBytes)
            }
        } catch let error as FileManagerError {
            throw error
        } catch {
            Log.warning("Could not check file size: \(error.localizedDescription)", subsystem: .file)
        }
        
        let filename = UUID().uuidString + "." + ext
        
        guard let destURL = imageURL(for: filename) else {
            throw FileManagerError.invalidData
        }
        
        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
            Log.info("Copied image: \(sourceURL.lastPathComponent) → \(filename)", subsystem: .file)
        } catch {
            Log.error("Failed to copy image", error: error, subsystem: .file)
            throw FileManagerError.copyFailed(source: sourceURL, destination: destURL, error)
        }
        
        // Generate thumbnail asynchronously
        Task.detached(priority: .utility) {
            await generateThumbnailAsync(from: destURL, filename: filename)
        }
        
        return filename
    }
    
    // MARK: - Format Detection
    
    private static func detectImageFormat(from data: Data) -> String? {
        guard data.count >= 12 else { return nil }
        
        let bytes = [UInt8](data.prefix(12))
        
        // Check known signatures
        for (signature, ext) in imageSignatures {
            if bytes.starts(with: signature) {
                // Special handling for WebP (need to check WEBP marker)
                if ext == "webp" {
                    guard data.count >= 12 else { continue }
                    let webpMarker = [UInt8](data[8..<12])
                    if webpMarker == [0x57, 0x45, 0x42, 0x50] {
                        return "webp"
                    }
                    continue
                }
                return ext
            }
        }
        
        // Check for SVG (text-based)
        if let str = String(data: data.prefix(1000), encoding: .utf8) {
            let lowercased = str.lowercased()
            if lowercased.contains("<svg") || (lowercased.contains("<?xml") && lowercased.contains("svg")) {
                return "svg"
            }
        }
        
        return nil
    }
    
    // MARK: - Load Images
    
    static func loadImage(filename: String) -> NSImage? {
        guard let url = imageURL(for: filename) else { return nil }
        
        guard fileManager.fileExists(atPath: url.path) else {
            Log.warning("Image file not found: \(filename)", subsystem: .file)
            return nil
        }
        
        if isSVG(filename: filename) {
            return loadSVGImage(from: url)
        }
        
        guard let image = NSImage(contentsOf: url) else {
            Log.warning("Failed to load image: \(filename)", subsystem: .file)
            return nil
        }
        
        return image
    }
    
    static func loadThumbnail(filename: String) -> NSImage? {
        guard let url = thumbnailURL(for: filename) else { return nil }
        
        guard fileManager.fileExists(atPath: url.path) else {
            // Thumbnail might not exist yet - try to regenerate
            if let imageURL = imageURL(for: filename), fileManager.fileExists(atPath: imageURL.path) {
                Task.detached(priority: .utility) {
                    await generateThumbnailAsync(from: imageURL, filename: filename)
                }
            }
            return nil
        }
        
        return NSImage(contentsOf: url)
    }
    
    private static func loadSVGImage(from url: URL) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        
        // SVGs can report zero size - set reasonable default
        if image.size.width <= 0 || image.size.height <= 0 {
            image.size = NSSize(width: 512, height: 512)
        }
        
        return image
    }
    
    // MARK: - Delete Image
    
    static func deleteImage(filename: String) {
        guard !filename.isEmpty else { return }
        
        // Delete main image
        if let imageURL = imageURL(for: filename), fileManager.fileExists(atPath: imageURL.path) {
            do {
                try fileManager.removeItem(at: imageURL)
                Log.info("Deleted image: \(filename)", subsystem: .file)
            } catch {
                Log.error("Failed to delete image: \(filename)", error: error, subsystem: .file)
            }
        }
        
        // Delete thumbnail
        if let thumbURL = thumbnailURL(for: filename), fileManager.fileExists(atPath: thumbURL.path) {
            do {
                try fileManager.removeItem(at: thumbURL)
            } catch {
                Log.warning("Failed to delete thumbnail for: \(filename)", subsystem: .file)
            }
        }
    }
    
    // MARK: - Thumbnail Generation
    
    @MainActor
    private static func generateThumbnailAsync(from imageURL: URL, filename: String) async {
        let maxDimension = Config.thumbnailSize
        
        guard let thumbURL = thumbnailURL(for: filename) else { return }
        
        // Skip if thumbnail already exists
        if fileManager.fileExists(atPath: thumbURL.path) { return }
        
        do {
            if isSVG(filename: filename) {
                guard let thumbnail = renderSVGThumbnail(from: imageURL, maxSize: maxDimension),
                      let pngData = thumbnail.pngData else {
                    throw FileManagerError.thumbnailGenerationFailed(filename)
                }
                try pngData.write(to: thumbURL, options: .atomic)
            } else {
                guard let image = NSImage(contentsOf: imageURL),
                      image.size.width > 0, image.size.height > 0 else {
                    throw FileManagerError.thumbnailGenerationFailed(filename)
                }
                
                let newSize = calculateThumbnailSize(originalSize: image.size, maxDimension: maxDimension)
                
                guard let thumbnail = renderImageToSize(image, size: newSize),
                      let pngData = thumbnail.pngData else {
                    throw FileManagerError.thumbnailGenerationFailed(filename)
                }
                
                try pngData.write(to: thumbURL, options: .atomic)
            }
            
            Log.debug("Generated thumbnail: \(filename)", subsystem: .file)
        } catch {
            Log.warning("Thumbnail generation failed for \(filename): \(error.localizedDescription)", subsystem: .file)
        }
    }
    
    private static func calculateThumbnailSize(originalSize: NSSize, maxDimension: CGFloat) -> NSSize {
        guard originalSize.width > 0, originalSize.height > 0 else {
            return NSSize(width: maxDimension, height: maxDimension)
        }
        
        let aspectRatio = originalSize.width / originalSize.height
        
        if aspectRatio > 1 {
            return NSSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            return NSSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
    }
    
    private static func renderSVGThumbnail(from url: URL, maxSize: CGFloat) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        
        var size = image.size
        if size.width <= 0 || size.height <= 0 {
            size = NSSize(width: 100, height: 100)
        }
        
        let targetSize = calculateThumbnailSize(originalSize: size, maxDimension: maxSize)
        return renderImageToSize(image, size: targetSize)
    }
    
    private static func renderImageToSize(_ image: NSImage, size: NSSize) -> NSImage? {
        let pixelWidth = Int(size.width * Config.retinaScale)
        let pixelHeight = Int(size.height * Config.retinaScale)
        
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }
        
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        
        bitmapRep.size = size  // Points, not pixels
        
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else { return nil }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        context.shouldAntialias = true
        
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        
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
