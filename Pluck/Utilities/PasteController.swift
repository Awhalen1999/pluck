//
//  PasteController.swift
//  Pluck
//
//  Manages paste operations from clipboard to folders.
//  Thread-safe with proper validation and feedback.
//

import Foundation
import SwiftData

// MARK: - Paste Controller

@Observable
@MainActor
final class PasteController {
    
    // MARK: - State
    
    /// The folder currently being hovered (for paste targeting)
    var hoveredFolderID: UUID?
    
    /// Triggers when a paste succeeds (for UI feedback) - auto-clears
    var lastPastedFolderID: UUID?
    
    // MARK: - Dependencies
    
    private let windowManager: WindowManager
    private let clipboardWatcher: ClipboardWatcher
    
    // MARK: - Configuration
    
    private enum Config {
        static let feedbackClearDelay: TimeInterval = 0.5
    }
    
    // MARK: - Computed Properties
    
    /// Whether clipboard has an image available
    var hasImageToPaste: Bool {
        clipboardWatcher.hasImage
    }
    
    /// Whether paste UI should be shown (window active + has image)
    var canShowPasteUI: Bool {
        windowManager.isWindowActive && clipboardWatcher.hasImage
    }
    
    /// Whether a paste operation can be attempted
    var canPaste: Bool {
        windowManager.isWindowActive && clipboardWatcher.hasImage
    }
    
    // MARK: - Initialization
    
    init(windowManager: WindowManager, clipboardWatcher: ClipboardWatcher) {
        self.windowManager = windowManager
        self.clipboardWatcher = clipboardWatcher
        Log.debug("PasteController initialized", subsystem: .clipboard)
    }
    
    // MARK: - Paste Actions
    
    /// Paste clipboard image to a specific folder
    /// Returns true on success, false on failure
    @discardableResult
    func pasteToFolder(_ folder: DesignFolder, modelContext: ModelContext) -> Bool {
        Log.debug("Attempting paste to folder: \(folder.name)", subsystem: .clipboard)
        
        // Validate window is active
        guard windowManager.isWindowActive else {
            Log.debug("Paste blocked: window not active", subsystem: .clipboard)
            return false
        }
        
        // Get image data
        guard let imageData = clipboardWatcher.getImageData() else {
            Log.debug("Paste blocked: no image in clipboard", subsystem: .clipboard)
            return false
        }
        
        // Save image
        do {
            let filename = try FileManagerHelper.saveImage(imageData, originalName: "Pasted Image")
            
            let newImage = DesignImage(
                filename: filename,
                originalName: "Pasted Image",
                sortOrder: folder.images.count,
                folder: folder
            )
            
            modelContext.insert(newImage)
            
            // Save context
            do {
                try modelContext.save()
            } catch {
                Log.error("Failed to save model context after paste", error: error, subsystem: .data)
                // Don't fail the paste - the image is saved, just not persisted to DB yet
            }
            
            // Trigger UI feedback
            triggerPasteFeedback(for: folder.id)
            
            Log.info("Successfully pasted image to '\(folder.name)'", subsystem: .clipboard)
            return true
            
        } catch {
            Log.error("Failed to save pasted image", error: error, subsystem: .clipboard)
            return false
        }
    }
    
    /// Paste to the currently hovered folder (if any)
    @discardableResult
    func pasteToHoveredFolder(folders: [DesignFolder], modelContext: ModelContext) -> Bool {
        guard let hoveredID = hoveredFolderID else {
            Log.debug("Paste blocked: no hovered folder", subsystem: .clipboard)
            return false
        }
        
        guard let folder = folders.first(where: { $0.id == hoveredID }) else {
            Log.warning("Hovered folder ID not found in folders list", subsystem: .clipboard)
            hoveredFolderID = nil  // Clear invalid state
            return false
        }
        
        return pasteToFolder(folder, modelContext: modelContext)
    }
    
    // MARK: - Hover Management
    
    /// Set the currently hovered folder
    func setHoveredFolder(_ folderID: UUID?) {
        guard hoveredFolderID != folderID else { return }
        hoveredFolderID = folderID
    }
    
    /// Clear the hovered folder
    func clearHoveredFolder() {
        hoveredFolderID = nil
    }
    
    // MARK: - Feedback Management
    
    private func triggerPasteFeedback(for folderID: UUID) {
        lastPastedFolderID = folderID
        
        // Auto-clear feedback after delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Config.feedbackClearDelay))
            if lastPastedFolderID == folderID {
                lastPastedFolderID = nil
            }
        }
    }
    
    /// Manually clear the paste feedback (for UI coordination)
    func clearPasteFeedback() {
        lastPastedFolderID = nil
    }
}
