//
//  FolderListView.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct FolderListView: View {
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DesignFolder.sortOrder) private var folders: [DesignFolder]
    
    @State private var isAddingFolder = false
    
    // Drag reorder state
    @State private var draggingIndex: Int?
    @State private var targetIndex: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            header
            folderList
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        PanelHeader(
            title: "Folders",
            onClose: { windowManager.collapse() }
        )
    }
    
    // MARK: - Folder List
    
    private var folderList: some View {
        ScrollView {
            LazyVStack(spacing: PanelDimensions.folderCardSpacing) {
                ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                    FolderCardView(
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
                }
                
                NewFolderCard(isAdding: $isAddingFolder) { name, colorHex in
                    createFolder(name: name, colorHex: colorHex)
                }
            }
            .padding(PanelDimensions.contentPadding)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: targetIndex)
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
            // Dragging down: items between dragging and target shift UP
            if index > dragging && index <= target {
                return -itemHeight
            }
        } else if dragging > target {
            // Dragging up: items between target and dragging shift DOWN
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
        defer {
            draggingIndex = nil
            targetIndex = nil
        }
        
        guard let fromIndex = draggingIndex,
              let toIndex = targetIndex,
              fromIndex != toIndex else { return }
        
        // Reorder the folders
        var sorted = folders.sorted { $0.sortOrder < $1.sortOrder }
        let moved = sorted.remove(at: fromIndex)
        sorted.insert(moved, at: toIndex)
        
        // Update sort orders
        for (index, folder) in sorted.enumerated() {
            folder.sortOrder = index
        }
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

// MARK: - Comparable Extension

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview {
    FolderListView()
        .environment(WindowManager())
        .modelContainer(for: [DesignFolder.self, DesignImage.self])
        .frame(width: 220, height: 350)
        .background(Color.black.opacity(0.8))
}
