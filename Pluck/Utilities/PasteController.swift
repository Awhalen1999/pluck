//
//  PasteController.swift
//  Pluck
//

import Foundation
import SwiftData

/// Centralized paste handling that routes based on current panel state.
@Observable
@MainActor
final class PasteController {
    
    // MARK: - Dependencies
    
    private let windowManager: WindowManager
    private let clipboardWatcher: ClipboardWatcher
    private var modelContainer: ModelContainer?
    
    // MARK: - State
    
    /// Currently hovered folder ID (set by FolderListView)
    var hoveredFolderID: UUID?
    
    // MARK: - Initialization
    
    init(windowManager: WindowManager, clipboardWatcher: ClipboardWatcher) {
        self.windowManager = windowManager
        self.clipboardWatcher = clipboardWatcher
    }
    
    func setModelContainer(_ container: ModelContainer) {
        self.modelContainer = container
    }
    
    // MARK: - Paste Handling
    
    /// Attempts to paste clipboard image based on current state.
    /// Returns true if paste was handled.
    func handlePaste() -> Bool {
        guard clipboardWatcher.hasImage,
              let imageData = clipboardWatcher.getImageData() else {
            return false
        }
        
        switch windowManager.panelState {
        case .collapsed:
            return false
            
        case .folderList:
            return pasteToHoveredFolder(imageData)
            
        case .folderOpen(let folder):
            return pasteToFolder(folder, imageData: imageData)
            
        case .imageFocused:
            if let folder = windowManager.activeFolder {
                return pasteToFolder(folder, imageData: imageData)
            }
            return false
        }
    }
    
    // MARK: - Private
    
    private func pasteToHoveredFolder(_ imageData: Data) -> Bool {
        guard let folderID = hoveredFolderID,
              let context = modelContainer?.mainContext else {
            return false
        }
        
        let descriptor = FetchDescriptor<DesignFolder>(
            predicate: #Predicate { $0.id == folderID }
        )
        
        guard let folder = try? context.fetch(descriptor).first else {
            return false
        }
        
        return pasteToFolder(folder, imageData: imageData)
    }
    
    private func pasteToFolder(_ folder: DesignFolder, imageData: Data) -> Bool {
        guard let context = modelContainer?.mainContext else {
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
            context.insert(newImage)
            return true
        } catch {
            print("Failed to paste image: \(error)")
            return false
        }
    }
}
