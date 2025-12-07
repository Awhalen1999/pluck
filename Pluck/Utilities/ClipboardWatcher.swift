//
//  ClipboardWatcher.swift
//  Pluck
//

import Foundation
import AppKit
import Combine

@Observable
final class ClipboardWatcher {
    
    // MARK: - Published State
    
    private(set) var hasImage: Bool = false
    
    // MARK: - Private
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let checkInterval: TimeInterval = 0.5
    
    // MARK: - Lifecycle
    
    init() {
        startWatching()
    }
    
    deinit {
        stopWatching()
    }
    
    // MARK: - Watching
    
    func startWatching() {
        // Initial check
        checkClipboard()
        
        // Periodic check
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
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png, .tiff, .fileURL
        ]
        
        // If pasteboard directly contains image data of any allowed type
        if pasteboard.canReadItem(withDataConformingToTypes: imageTypes.map(\.rawValue)) {
            return true
        }
        
        // If the pasteboard contains files, verify their extension
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            return urls.contains { url in
                ["png", "jpg", "jpeg", "gif", "webp", "tiff", "bmp", "heic"]
                    .contains(url.pathExtension.lowercased())
            }
        }
        
        return false
    }
    
    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "tiff", "bmp", "heic"]
        return imageExtensions.contains(url.pathExtension.lowercased())
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
