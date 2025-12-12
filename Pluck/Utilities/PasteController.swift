//
//  PasteController.swift
//  Pluck
//

import Foundation
import SwiftData

@Observable
final class PasteController {
    
    // MARK: - State
    
    /// The folder currently being hovered (for paste targeting)
    var hoveredFolderID: UUID?
    
    // MARK: - Dependencies
    
    private let windowManager: WindowManager
    private let clipboardWatcher: ClipboardWatcher
    
    // MARK: - Computed
    
    var hasImageToPaste: Bool {
        clipboardWatcher.hasImage
    }
    
    /// Whether paste UI should be shown (window active + has image)
    var canShowPasteUI: Bool {
        windowManager.isWindowActive && clipboardWatcher.hasImage
    }
    
    // MARK: - Init
    
    init(windowManager: WindowManager, clipboardWatcher: ClipboardWatcher) {
        self.windowManager = windowManager
        self.clipboardWatcher = clipboardWatcher
    }
    
    // MARK: - Paste Action
    
    /// Paste clipboard image to a specific folder
    func pasteToFolder(_ folder: DesignFolder, modelContext: ModelContext) -> Bool {
        guard let imageData = clipboardWatcher.getImageData() else {
            return false
        }
        
        do {
            let filename = try FileManagerHelper.saveImage(imageData, originalName: "Pasted Image")
            let newImage = DesignImage(
                filename: filename,
                originalName: "Pasted Image",
                sortOrder: folder.images.count,
                folder: folder
            )
            modelContext.insert(newImage)
            return true
        } catch {
            print("Failed to paste image: \(error)")
            return false
        }
    }
    
    /// Paste to the currently hovered folder (if any)
    func pasteToHoveredFolder(folders: [DesignFolder], modelContext: ModelContext) -> Bool {
        guard let hoveredID = hoveredFolderID,
              let folder = folders.first(where: { $0.id == hoveredID }) else {
            return false
        }
        
        return pasteToFolder(folder, modelContext: modelContext)
    }
}
