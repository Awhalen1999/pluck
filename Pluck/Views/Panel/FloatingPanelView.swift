//
//  FloatingPanelView.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct FloatingPanelView: View {
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.modelContext) private var modelContext
    @Environment(ClipboardWatcher.self) private var clipboardWatcher
    @Environment(PasteController.self) private var pasteController
    
    var body: some View {
        VStack(spacing: 0) {
            // The icon/header is always present
            panelIcon
            
            // Content expands below when not collapsed
            if !isCollapsed {
                expandedContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(
            width: currentWidth,
            height: currentHeight
        )
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Theme.border, lineWidth: 1)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: windowManager.panelState)
    }
    
    // MARK: - State Helpers
    
    private var isCollapsed: Bool {
        if case .collapsed = windowManager.panelState {
            return true
        }
        return false
    }
    
    // MARK: - Panel Icon (Always Visible)
    
    private var panelIcon: some View {
        PanelIconView()
            .frame(
                width: PanelDimensions.collapsedSize.width,
                height: PanelDimensions.collapsedSize.height
            )
    }
    
    // MARK: - Expanded Content
    
    @ViewBuilder
    private var expandedContent: some View {
        switch windowManager.panelState {
        case .collapsed:
            EmptyView()
            
        case .folderList:
            FolderListContentView()
                
        case .folderOpen(let folder):
            FolderDetailContentView(folder: folder)
                
        case .imageFocused(let image):
            ImageDetailContentView(image: image)
        }
    }
    
    // MARK: - Dynamic Dimensions
    
    private var currentWidth: CGFloat {
        switch windowManager.panelState {
        case .collapsed:
            return PanelDimensions.collapsedSize.width
        case .folderList, .folderOpen:
            return PanelDimensions.folderListSize.width
        case .imageFocused:
            return PanelDimensions.imageDetailSize.width
        }
    }
    
    private var currentHeight: CGFloat {
        switch windowManager.panelState {
        case .collapsed:
            return PanelDimensions.collapsedSize.height
        case .folderList, .folderOpen:
            let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
            return PanelDimensions.collapsedSize.height + PanelDimensions.listHeight(screenHeight: screenHeight)
        case .imageFocused:
            return PanelDimensions.collapsedSize.height + PanelDimensions.imageDetailSize.height
        }
    }
    
    // MARK: - Styling
    
    private var cornerRadius: CGFloat {
        isCollapsed ? PanelDimensions.collapsedCornerRadius : PanelDimensions.expandedCornerRadius
    }
    
    private var panelBackground: some View {
        ZStack {
            Theme.backgroundSolid
            
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .opacity(0.3)
        }
    }
}

// MARK: - Panel Icon View

/// The always-visible icon that acts as both collapsed state and header for expanded states
private struct PanelIconView: View {
    @Environment(WindowManager.self) private var windowManager
    
    @State private var isDragging = false
    @State private var holdTimer: Timer?
    @State private var canDrag = false
    @State private var isWiggling = false
    @State private var isDropTargeted = false
    
    private let holdDuration: TimeInterval = 0.8
    
    var body: some View {
        Image(systemName: "square.stack.3d.up.fill")
            .font(.system(size: 22))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: PanelDimensions.collapsedCornerRadius)
                    .fill(isDragging ? Theme.backgroundCardHover : .clear)
            )
            .scaleEffect(scaleEffect)
            .wiggle(when: $isWiggling)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDragging)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onDrop(of: ["public.image", "public.file-url"], isTargeted: $isDropTargeted) { _ in
                false
            }
            .onChange(of: isDropTargeted) { _, targeted in
                if targeted && isCollapsed {
                    windowManager.showFolderList()
                }
            }
            .onDisappear {
                invalidateTimer()
            }
    }
    
    private var isCollapsed: Bool {
        if case .collapsed = windowManager.panelState {
            return true
        }
        return false
    }
    
    private var scaleEffect: CGFloat {
        if isDragging { return 1.08 }
        if isDropTargeted { return 1.05 }
        return 1.0
    }
    
    // MARK: - Timer
    
    private func invalidateTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
    }
    
    // MARK: - Drag Gesture
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleDragChanged(value)
            }
            .onEnded { _ in
                handleDragEnded()
            }
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        if holdTimer == nil && !canDrag {
            holdTimer = Timer(timeInterval: holdDuration, repeats: false) { _ in
                DispatchQueue.main.async {
                    canDrag = true
                    isDragging = true
                    isWiggling = true
                }
            }
            RunLoop.current.add(holdTimer!, forMode: .common)
        }
        
        if canDrag {
            moveWindowVertically(by: value.translation.height)
        }
    }
    
    private func handleDragEnded() {
        invalidateTimer()
        
        if !canDrag {
            // Quick tap - toggle expansion
            if isCollapsed {
                windowManager.showFolderList()
            }
        } else {
            saveYPosition()
        }
        
        isWiggling = false
        isDragging = false
        canDrag = false
    }
    
    // MARK: - Window Movement
    
    private func moveWindowVertically(by deltaY: CGFloat) {
        guard let window = NSApplication.shared.windows.first(where: { $0 is FloatingPanel }),
              let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        var frame = window.frame
        
        frame.origin.y -= deltaY
        frame.origin.y = frame.origin.y.clamped(
            to: screenRect.minY + PanelDimensions.edgeMargin...screenRect.maxY - frame.height - PanelDimensions.edgeMargin
        )
        
        window.setFrameOrigin(frame.origin)
    }
    
    private func saveYPosition() {
        guard let window = NSApplication.shared.windows.first(where: { $0 is FloatingPanel }),
              let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let frame = window.frame
        let yFromTop = screenRect.maxY - frame.origin.y - frame.height
        windowManager.dockedYPosition = yFromTop
    }
}

// MARK: - Content Views (Without Headers)

/// Folder list content (no header needed - icon is the header)
private struct FolderListContentView: View {
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.modelContext) private var modelContext
    @Environment(PasteController.self) private var pasteController
    @Query(sort: \DesignFolder.sortOrder) private var folders: [DesignFolder]
    
    @State private var isAddingFolder = false
    @State private var draggingIndex: Int?
    @State private var targetIndex: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            // Close button at top
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
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
                        .onHover { hovering in
                            pasteController.hoveredFolderID = hovering ? folder.id : nil
                        }
                    }
                    
                    NewFolderCard(isAdding: $isAddingFolder) { name, colorHex in
                        createFolder(name: name, colorHex: colorHex)
                    }
                }
                .padding(PanelDimensions.contentPadding)
                .animation(draggingIndex != nil ? .spring(response: 0.3, dampingFraction: 0.75) : nil, value: targetIndex)
            }
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
    
    private func createFolder(name: String, colorHex: String) {
        let folder = DesignFolder(
            name: name,
            colorHex: colorHex,
            sortOrder: folders.count
        )
        modelContext.insert(folder)
    }
}

/// Folder detail content
private struct FolderDetailContentView: View {
    let folder: DesignFolder
    
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.modelContext) private var modelContext
    @Environment(ClipboardWatcher.self) private var clipboardWatcher
    
    @State private var isDropTargeted = false
    
    private let columns = [
        GridItem(.flexible(), spacing: PanelDimensions.thumbnailSpacing),
        GridItem(.flexible(), spacing: PanelDimensions.thumbnailSpacing),
        GridItem(.flexible(), spacing: PanelDimensions.thumbnailSpacing)
    ]
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerBar
                content
            }
            .dropTarget(
                isTargeted: $isDropTargeted,
                cornerRadius: PanelDimensions.expandedCornerRadius
            ) { providers in
                handleDrop(providers)
            }
            
            PasteOverlay(isVisible: clipboardWatcher.hasImage)
        }
    }
    
    private var headerBar: some View {
        HStack {
            Button(action: { windowManager.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: folder.colorHex) ?? Theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Text(folder.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var content: some View {
        if folder.images.isEmpty {
            emptyState
        } else {
            imageGrid
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 28))
                .foregroundStyle(Theme.textTertiary)
            
            Text("Drop images here")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
            
            Spacer()
        }
    }
    
    private var imageGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: PanelDimensions.thumbnailSpacing) {
                ForEach(folder.sortedImages) { image in
                    ThumbnailView(
                        image: image,
                        size: PanelDimensions.thumbnailSize,
                        cornerRadius: PanelDimensions.thumbnailCornerRadius
                    )
                    .onTapGesture {
                        windowManager.focusImage(image)
                    }
                }
            }
            .padding(PanelDimensions.contentPadding - 2)
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in
                    guard let data = data else { return }
                    
                    DispatchQueue.main.async {
                        saveImage(data)
                    }
                }
                return true
            }
        }
        return false
    }
    
    private func saveImage(_ data: Data) {
        do {
            let filename = try FileManagerHelper.saveImage(data, originalName: "Dropped Image")
            let newImage = DesignImage(
                filename: filename,
                originalName: "Dropped Image",
                sortOrder: folder.images.count,
                folder: folder
            )
            modelContext.insert(newImage)
        } catch {
            Logger.error("Failed to save image", error: error)
        }
    }
}

/// Image detail content
private struct ImageDetailContentView: View {
    let image: DesignImage
    
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var fullImage: NSImage?
    @State private var isHoveringDelete = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            Divider()
                .background(Theme.border)
            
            imageContent
            
            if let sourceURL = image.sourceURL, !sourceURL.isEmpty {
                sourceURLBar(sourceURL)
            }
        }
        .onAppear {
            loadFullImage()
        }
    }
    
    private var headerBar: some View {
        HStack {
            Button(action: { windowManager.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Text(image.originalName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .padding(.leading, 8)
            
            Spacer()
            
            Button(action: deleteImage) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(isHoveringDelete ? .red : Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .onHover { isHoveringDelete = $0 }
            .padding(.trailing, 8)
            
            Button(action: { windowManager.collapse() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PanelDimensions.contentPadding)
        .padding(.top, PanelDimensions.contentPadding)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var imageContent: some View {
        if let fullImage = fullImage {
            Image(nsImage: fullImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(PanelDimensions.contentPadding)
                .onDrag {
                    NSItemProvider(object: fullImage)
                }
        } else {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Spacer()
        }
    }
    
    private func sourceURLBar(_ urlString: String) -> some View {
        VStack(spacing: 0) {
            Divider()
                .background(Theme.border)
            
            HStack {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                
                Text(urlString)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { copyToClipboard(urlString) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, PanelDimensions.contentPadding + 4)
            .padding(.vertical, 10)
        }
    }
    
    private func loadFullImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = FileManagerHelper.loadImage(filename: image.filename)
            DispatchQueue.main.async {
                self.fullImage = loaded
            }
        }
    }
    
    private func deleteImage() {
        FileManagerHelper.deleteImage(filename: image.filename)
        modelContext.delete(image)
        windowManager.goBack()
    }
    
    private func copyToClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

// MARK: - Preview

#Preview {
    FloatingPanelView()
        .environment(WindowManager())
        .environment(ClipboardWatcher())
        .environment(PasteController(windowManager: WindowManager(), clipboardWatcher: ClipboardWatcher()))
        .modelContainer(for: [DesignFolder.self, DesignImage.self])
}
