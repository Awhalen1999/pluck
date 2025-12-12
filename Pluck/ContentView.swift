//
//  ContentView.swift
//  Pluck
//
//  Routes between content views. Manages its own navigation state.
//

import SwiftUI

// MARK: - Content State

enum ContentState: Equatable {
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
}

// MARK: - Content View

struct ContentView: View {
    @Environment(WindowManager.self) private var windowManager
    
    @State private var contentState: ContentState = .folderList
    @State private var activeFolder: DesignFolder?
    
    var body: some View {
        ZStack {
            switch contentState {
            case .folderList:
                FolderListView(onSelectFolder: openFolder)
                    .transition(.opacity)
                
            case .folderDetail(let folder):
                FolderDetailView(
                    folder: folder,
                    onBack: goBack,
                    onSelectImage: openImage,
                    onDelete: { handleFolderDeleted() }
                )
                .transition(.opacity)
                
            case .imageDetail(let image):
                ImageDetailView(
                    image: image,
                    onBack: goBack,
                    onDelete: { handleImageDeleted() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: contentState)
        .onChange(of: windowManager.isOpen) { _, isOpen in
            if !isOpen {
                // Reset to folder list when panel closes
                activeFolder = nil
                contentState = .folderList
            }
        }
    }
    
    // MARK: - Navigation
    
    private func openFolder(_ folder: DesignFolder) {
        activeFolder = folder
        contentState = .folderDetail(folder)
    }
    
    private func openImage(_ image: DesignImage) {
        contentState = .imageDetail(image)
    }
    
    private func goBack() {
        switch contentState {
        case .folderList:
            windowManager.close()
        case .folderDetail:
            activeFolder = nil
            contentState = .folderList
        case .imageDetail:
            if let folder = activeFolder {
                contentState = .folderDetail(folder)
            } else {
                contentState = .folderList
            }
        }
    }
    
    private func handleFolderDeleted() {
        activeFolder = nil
        contentState = .folderList
    }
    
    private func handleImageDeleted() {
        // Go back to folder detail
        if let folder = activeFolder {
            contentState = .folderDetail(folder)
        } else {
            contentState = .folderList
        }
    }
}
