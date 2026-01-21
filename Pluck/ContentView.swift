//
//  ContentView.swift
//  Pluck
//
//  Routes between content views. Manages navigation state with proper lifecycle.
//

import SwiftUI

// MARK: - Content State

enum ContentState: Equatable, CustomStringConvertible {
    case folderList
    case folderDetail(DesignFolder)
    case imageDetail(DesignImage)
    
    static func == (lhs: ContentState, rhs: ContentState) -> Bool {
        switch (lhs, rhs) {
        case (.folderList, .folderList):
            return true
        case (.folderDetail(let a), .folderDetail(let b)):
            return a.id == b.id
        case (.imageDetail(let a), .imageDetail(let b)):
            return a.id == b.id
        default:
            return false
        }
    }
    
    var description: String {
        switch self {
        case .folderList:
            return "folderList"
        case .folderDetail(let folder):
            return "folderDetail(\(folder.name))"
        case .imageDetail(let image):
            return "imageDetail(\(image.originalName))"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @Environment(WindowManager.self) private var windowManager
    
    @State private var contentState: ContentState = .folderList
    @State private var activeFolder: DesignFolder?
    
    // MARK: - Animation Config
    
    private let transitionDuration: TimeInterval = 0.2
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            contentForState
        }
        .animation(.easeOut(duration: transitionDuration), value: contentState)
        .onChange(of: windowManager.isOpen) { _, isOpen in
            handlePanelStateChange(isOpen: isOpen)
        }
    }
    
    // MARK: - Content Routing
    
    @ViewBuilder
    private var contentForState: some View {
        switch contentState {
        case .folderList:
            FolderListView(onSelectFolder: openFolder)
                .transition(.opacity)
            
        case .folderDetail(let folder):
            FolderDetailView(
                folder: folder,
                onBack: goBack,
                onSelectImage: openImage,
                onDelete: handleFolderDeleted
            )
            .transition(.opacity)
            
        case .imageDetail(let image):
            ImageDetailView(
                image: image,
                onBack: goBack,
                onDelete: handleImageDeleted
            )
            .transition(.opacity)
        }
    }
    
    // MARK: - Navigation Actions
    
    private func openFolder(_ folder: DesignFolder) {
        Log.debug("Opening folder: \(folder.name)", subsystem: .ui)
        activeFolder = folder
        contentState = .folderDetail(folder)
    }
    
    private func openImage(_ image: DesignImage) {
        Log.debug("Opening image: \(image.originalName)", subsystem: .ui)
        contentState = .imageDetail(image)
    }
    
    private func goBack() {
        Log.debug("Navigation: goBack from \(contentState)", subsystem: .ui)
        
        switch contentState {
        case .folderList:
            // At root - close the panel
            windowManager.close()
            
        case .folderDetail:
            // Go back to folder list
            activeFolder = nil
            contentState = .folderList
            
        case .imageDetail:
            // Go back to folder detail or folder list
            if let folder = activeFolder {
                contentState = .folderDetail(folder)
            } else {
                contentState = .folderList
            }
        }
    }
    
    // MARK: - Deletion Handlers
    
    private func handleFolderDeleted() {
        Log.debug("Folder deleted, returning to list", subsystem: .ui)
        activeFolder = nil
        contentState = .folderList
    }
    
    private func handleImageDeleted() {
        Log.debug("Image deleted, returning to folder", subsystem: .ui)
        if let folder = activeFolder {
            contentState = .folderDetail(folder)
        } else {
            contentState = .folderList
        }
    }
    
    // MARK: - Panel State Handling
    
    private func handlePanelStateChange(isOpen: Bool) {
        if !isOpen {
            // Reset navigation when panel closes
            Log.debug("Panel closed, resetting navigation", subsystem: .ui)
            activeFolder = nil
            contentState = .folderList
        }
    }
}

// MARK: - Preview

#Preview("Folder List") {
    ContentView()
        .environment(WindowManager())
        .frame(width: 225, height: 400)
}
