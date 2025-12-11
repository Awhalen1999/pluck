//
//  FolderListView.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct FolderListView: View {
    let onSelectFolder: (DesignFolder) -> Void
    
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DesignFolder.sortOrder) private var folders: [DesignFolder]
    
    @State private var isAddingFolder = false
    @State private var draggingIndex: Int?
    @State private var targetIndex: Int?
    
    // MARK: - Constants
    
    private let cardHeight: CGFloat = 68
    private let cardSpacing: CGFloat = 8
    private let contentPadding: CGFloat = 12
    
    var body: some View {
        VStack(spacing: 0) {
            header
            folderList
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Spacer()
            
            Button(action: { windowManager.close() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
    }
    
    // MARK: - Folder List
    
    private var folderList: some View {
        ScrollView {
            LazyVStack(spacing: cardSpacing) {
                ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                    FolderCard(
                        folder: folder,
                        onTap: { onSelectFolder(folder) },
                        onDragStarted: { startDragging(at: index) },
                        onDragChanged: { updateTargetIndex(from: index, translation: $0) },
                        onDragEnded: { commitReorder() }
                    )
                    .offset(y: offsetForIndex(index))
                    .zIndex(draggingIndex == index ? 100 : 0)
                }
                
                NewFolderCard(isAdding: $isAddingFolder) { name, colorHex in
                    createFolder(name: name, colorHex: colorHex)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, contentPadding)
            .animation(draggingIndex != nil ? .spring(response: 0.3, dampingFraction: 0.75) : nil, value: targetIndex)
        }
    }
    
    // MARK: - Drag Reorder
    
    private func startDragging(at index: Int) {
        draggingIndex = index
        targetIndex = index
    }
    
    private func offsetForIndex(_ index: Int) -> CGFloat {
        guard let dragging = draggingIndex, let target = targetIndex else { return 0 }
        guard index != dragging else { return 0 }
        
        let itemHeight = cardHeight + cardSpacing
        
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
        let itemHeight = cardHeight + cardSpacing
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
