//
//  FolderListBody.swift
//  Pluck
//
//  Created by Alex Whalen on 2025-12-10.
//

import SwiftUI
import SwiftData

/// Implementation of the folder list with drag reordering and folder creation
struct FolderListBody: View {
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.modelContext) private var modelContext
    @Environment(PasteController.self) private var pasteController
    @Query(sort: \DesignFolder.sortOrder) private var folders: [DesignFolder]
    
    @State private var isAddingFolder = false
    @State private var draggingIndex: Int?
    @State private var targetIndex: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            closeButton
            scrollableList
        }
    }
    
    // MARK: - Close Button
    
    private var closeButton: some View {
        HStack {
            Spacer()
            Button(action: { windowManager.collapse() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
    
    // MARK: - Scrollable List
    
    private var scrollableList: some View {
        ScrollView {
            LazyVStack(spacing: PanelDimensions.folderCardSpacing) {
                ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                    FolderCard(
                        folder: folder,
                        onTap: { windowManager.openFolder(folder) },
                        onDragStarted: { startDragging(at: index) },
                        onDragChanged: { translation in
                            updateTargetIndex(from: index, translation: translation)
                        },
                        onDragEnded: { commitReorder() }
                    )
                    .offset(y: offsetForIndex(index))
                    .zIndex(draggingIndex == index ? 100 : 0)
                    .onHover { hovering in
                        pasteController.hoveredFolderID = hovering ? folder.id : nil
                    }
                }
                
                NewFolderCard(isAdding: $isAddingFolder) { name, colorHex in
                    createFolder(name: name, colorHex: colorHex)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, PanelDimensions.contentPadding)
            .animation(draggingIndex != nil ? .spring(response: 0.3, dampingFraction: 0.75) : nil, value: targetIndex)
        }
    }
    
    // MARK: - Drag Reorder Logic
    
    private func startDragging(at index: Int) {
        draggingIndex = index
        targetIndex = index
    }
    
    private func offsetForIndex(_ index: Int) -> CGFloat {
        guard let dragging = draggingIndex, let target = targetIndex else { return 0 }
        guard index != dragging else { return 0 }
        
        let itemHeight = PanelDimensions.folderCardHeight + PanelDimensions.folderCardSpacing
        
        if dragging < target {
            if index > dragging && index <= target {
                return -itemHeight
            }
        } else if dragging > target {
            if index >= target && index < dragging {
                return itemHeight
            }
        }
        
        return 0
    }
    
    private func updateTargetIndex(from originalIndex: Int, translation: CGSize) {
        let itemHeight = PanelDimensions.folderCardHeight + PanelDimensions.folderCardSpacing
        let dragOffset = Int(round(translation.height / itemHeight))
        let newIndex = (originalIndex + dragOffset).clamped(to: 0...folders.count - 1)
        
        if newIndex != targetIndex {
            targetIndex = newIndex
        }
    }
    
    private func commitReorder() {
        guard let fromIndex = draggingIndex,
              let toIndex = targetIndex,
              fromIndex != toIndex else {
            draggingIndex = nil
            targetIndex = nil
            return
        }
        
        var sorted = folders.sorted { $0.sortOrder < $1.sortOrder }
        let moved = sorted.remove(at: fromIndex)
        sorted.insert(moved, at: toIndex)
        
        for (index, folder) in sorted.enumerated() {
            folder.sortOrder = index
        }
        
        try? modelContext.save()
        
        draggingIndex = nil
        targetIndex = nil
    }
    
    // MARK: - Folder Creation
    
    private func createFolder(name: String, colorHex: String) {
        let folder = DesignFolder(
            name: name,
            colorHex: colorHex,
            sortOrder: folders.count
        )
        modelContext.insert(folder)
    }
}
