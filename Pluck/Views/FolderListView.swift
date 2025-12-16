//
//  FolderListView.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct FolderListView: View {
    let onSelectFolder: (DesignFolder) -> Void
    
    @Environment(WindowManager.self) private var windowManager
    @Environment(PasteController.self) private var pasteController
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DesignFolder.sortOrder) private var folders: [DesignFolder]
    
    @State private var isAddingFolder = false
    @State private var draggingIndex: Int?
    @State private var targetIndex: Int?
    @State private var isCloseHovered = false
    @State private var keyMonitor: Any?
    
    // MARK: - Constants
    
    private let cardHeight: CGFloat = 68
    private let cardSpacing: CGFloat = 8
    
    var body: some View {
        VStack(spacing: 0) {
            header
            folderList
        }
        .onAppear { setupKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
    }
    
    // MARK: - Keyboard Monitoring
    
    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
                if handlePaste() {
                    return nil
                }
            }
            return event
        }
    }
    
    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    // MARK: - Paste Handling
    
    @discardableResult
    private func handlePaste() -> Bool {
        guard windowManager.isWindowActive else { return false }
        return pasteController.pasteToHoveredFolder(folders: folders, modelContext: modelContext)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Spacer()
            IconButton(icon: "xmark", action: { windowManager.close() }, isInactive: !windowManager.isWindowActive)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xs)
    }
    
    // MARK: - Folder List
    
    private var folderList: some View {
        ScrollView(showsIndicators: false) {
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
                    .onHover { hovering in
                        pasteController.hoveredFolderID = hovering ? folder.id : nil
                    }
                }
                
                NewFolderCard(isAdding: $isAddingFolder) { name, colorHex in
                    createFolder(name: name, colorHex: colorHex)
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.md)
            .padding(.top, 2)
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
