//
//  ClipboardWatcher.swift
//  Pluck
//
//  Monitors the system pasteboard for image content.
//  Thread-safe with proper lifecycle management.
//

import Foundation
import AppKit

// MARK: - Clipboard Watcher

@Observable
@MainActor
final class ClipboardWatcher {
    
    // MARK: - Configuration
    
    private enum Config {
        static let checkInterval: TimeInterval = 0.5
        static let maxImageDataSize: Int = 50 * 1024 * 1024  // 50MB
    }
    
    // MARK: - State
    
    private(set) var hasImage: Bool = false
    
    // MARK: - Private
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var isWatching: Bool = false
    
    private static let supportedExtensions: Set<String> = FileManagerHelper.supportedImageExtensions
    
    private static let directImageTypes: [NSPasteboard.PasteboardType] = [
        .png,
        .tiff
    ]
    
    // MARK: - Lifecycle
    
    init() {
        Log.debug("ClipboardWatcher initialized", subsystem: .clipboard)
    }
    
    // MARK: - Public API
    
    func startWatching() {
        guard !isWatching else {
            Log.debug("Already watching clipboard", subsystem: .clipboard)
            return
        }
        
        isWatching = true
        lastChangeCount = NSPasteboard.general.changeCount
        
        // Initial check
        checkClipboard()
        
        // Create timer on main run loop with .common mode for reliable firing
        let newTimer = Timer(timeInterval: Config.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
        
        Log.info("Clipboard watching started", subsystem: .clipboard)
    }
    
    func stopWatching() {
        guard isWatching else { return }
        
        timer?.invalidate()
        timer = nil
        isWatching = false
        hasImage = false
        
        Log.info("Clipboard watching stopped", subsystem: .clipboard)
    }
    
    /// Get image data from clipboard if available
    func getImageData() -> Data? {
        let pasteboard = NSPasteboard.general
        
        // Try PNG first (preferred format)
        if let data = pasteboard.data(forType: .png) {
            guard data.count <= Config.maxImageDataSize else {
                Log.warning("Clipboard PNG data too large: \(data.count) bytes", subsystem: .clipboard)
                return nil
            }
            Log.debug("Retrieved PNG data from clipboard (\(data.count) bytes)", subsystem: .clipboard)
            return data
        }
        
        // Try TIFF
        if let data = pasteboard.data(forType: .tiff) {
            guard data.count <= Config.maxImageDataSize else {
                Log.warning("Clipboard TIFF data too large: \(data.count) bytes", subsystem: .clipboard)
                return nil
            }
            Log.debug("Retrieved TIFF data from clipboard (\(data.count) bytes)", subsystem: .clipboard)
            return data
        }
        
        // Try file URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            for url in urls {
                if Self.isImageFile(url) {
                    do {
                        let data = try Data(contentsOf: url)
                        guard data.count <= Config.maxImageDataSize else {
                            Log.warning("File data too large: \(data.count) bytes", subsystem: .clipboard)
                            continue
                        }
                        Log.debug("Retrieved image file from clipboard: \(url.lastPathComponent)", subsystem: .clipboard)
                        return data
                    } catch {
                        Log.warning("Failed to read clipboard file: \(error.localizedDescription)", subsystem: .clipboard)
                    }
                }
            }
        }
        
        Log.debug("No valid image data in clipboard", subsystem: .clipboard)
        return nil
    }
    
    /// Force refresh the clipboard state
    func refresh() {
        lastChangeCount = 0  // Force next check to update
        checkClipboard()
    }
    
    // MARK: - Private Methods
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        
        // Only check if clipboard changed
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        
        let newHasImage = pasteboardHasImage(pasteboard)
        
        // Only log and update if state changed
        if newHasImage != hasImage {
            hasImage = newHasImage
            Log.debug("Clipboard image state: \(hasImage)", subsystem: .clipboard)
        }
    }
    
    private func pasteboardHasImage(_ pasteboard: NSPasteboard) -> Bool {
        // Check for direct image data types
        for type in Self.directImageTypes {
            if pasteboard.data(forType: type) != nil {
                return true
            }
        }
        
        // Check for file URLs that are images
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            if urls.contains(where: { Self.isImageFile($0) }) {
                return true
            }
        }
        
        return false
    }
    
    private static func isImageFile(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }
}

// MARK: - Clipboard Watcher State

extension ClipboardWatcher {
    var state: String {
        if !isWatching { return "stopped" }
        return hasImage ? "has_image" : "empty"
    }
}
