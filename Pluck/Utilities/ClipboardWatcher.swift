//
//  ClipboardWatcher.swift
//  Pluck
//

import Foundation
import AppKit

@Observable
final class ClipboardWatcher {
    
    // MARK: - State
    
    private(set) var hasImage: Bool = false
    
    // MARK: - Private
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let checkInterval: TimeInterval = 0.5
    
    private let imageExtensions = Set(["png", "jpg", "jpeg", "gif", "webp", "tiff", "bmp", "heic"])
    
    // MARK: - Lifecycle
    
    init() {
        startWatching()
    }
    
    deinit {
        stopWatching()
    }
    
    // MARK: - Watching
    
    func startWatching() {
        checkClipboard()
        
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func stopWatching() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Clipboard Check
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        
        // Only check if clipboard changed
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        hasImage = pasteboardHasImage(pasteboard)
    }
    
    private func pasteboardHasImage(_ pasteboard: NSPasteboard) -> Bool {
        // Direct image data
        if pasteboard.canReadItem(withDataConformingToTypes: [
            NSPasteboard.PasteboardType.png.rawValue,
            NSPasteboard.PasteboardType.tiff.rawValue
        ]) {
            return true
        }
        
        // File URL that's an image
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            return urls.contains { isImageFile($0) }
        }
        
        return false
    }
    
    private func isImageFile(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    // MARK: - Get Image Data
    
    func getImageData() -> Data? {
        let pasteboard = NSPasteboard.general
        
        // Try PNG first
        if let data = pasteboard.data(forType: .png) {
            return data
        }
        
        // Try TIFF
        if let data = pasteboard.data(forType: .tiff) {
            return data
        }
        
        // Try file URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first,
           isImageFile(url) {
            return try? Data(contentsOf: url)
        }
        
        return nil
    }
}
