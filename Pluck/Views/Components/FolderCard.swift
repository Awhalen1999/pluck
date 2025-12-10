//
//  FolderCard.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct FolderCard: View {
    let folder: DesignFolder
    let onTap: () -> Void
    let onDragStarted: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Environment(ClipboardWatcher.self) private var clipboardWatcher
    @Environment(WindowManager.self) private var windowManager
    @Environment(PasteController.self) private var pasteController
    
    @State private var isHovered = false
    @State private var isDropTargeted = false
    @State private var thumbnails: [NSImage] = []
    @State private var showSuccessPulse = false
    
    // Drag state
    @State private var holdTimer: Timer?
    @State private var canDrag = false
    @State private var dragOffset: CGSize = .zero
    @State private var isWiggling = false
    
    private let holdDuration: TimeInterval = 0.5
    
    private var folderColor: Color {
        Color(hex: folder.colorHex) ?? .purple
    }
    
    private var showPasteBadge: Bool {
        isHovered && clipboardWatcher.hasImage && windowManager.isWindowActive
    }
    
    private var showDropBadge: Bool {
        isDropTargeted
    }
    
    var body: some View {
        cardContent
            .frame(height: PanelDimensions.folderCardHeight)
            .offset(dragOffset)
            .scaleEffect(canDrag ? 1.02 : 1.0)
            .shadow(color: canDrag ? Theme.shadowMedium : .clear, radius: canDrag ? 12 : 0, y: canDrag ? 6 : 0)
            .wiggle(when: $isWiggling, angle: 1.5)
            .pulse(on: $showSuccessPulse)
            .onChange(of: pasteController.lastPastedFolderID) { _, newID in
                if newID == folder.id {
                    showSuccessPulse = true
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: canDrag)
            .animation(.easeOut(duration: 0.15), value: isDropTargeted)
            .gesture(dragGesture)
            .onDrop(of: ["public.image", "public.file-url"], isTargeted: $isDropTargeted) { providers in
                handleImageDrop(providers)
            }
            .onDisappear {
                invalidateTimer()
            }
    }
    
    // MARK: - Card Content
    
    private var cardContent: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(folderColor)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 6) {
                titleRow
                thumbnailRow
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(cardBackground)
        .overlay(cardBorder)
        .onHover { isHovered = $0 }
        .onAppear { loadThumbnails() }
        .onChange(of: folder.images.count) { oldCount, newCount in
            if newCount > oldCount {
                loadThumbnails()
            }
        }
    }
    
    private var titleRow: some View {
        HStack {
            Text(folder.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            if showDropBadge {
                DropBadge()
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else if showPasteBadge {
                PasteBadge {
                    pasteFromClipboard()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else {
                Text("\(folder.imageCount) item\(folder.imageCount == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .animation(.easeOut(duration: 0.15), value: showPasteBadge)
        .animation(.easeOut(duration: 0.15), value: showDropBadge)
    }
    
    @ViewBuilder
    private var thumbnailRow: some View {
        if folder.images.isEmpty {
            ThumbnailStackEmptyView()
        } else {
            ThumbnailStackView(
                thumbnails: thumbnails,
                totalCount: folder.imageCount
            )
        }
    }
    
    // MARK: - Styling
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: PanelDimensions.folderCardCornerRadius)
            .fill(backgroundFill)
    }
    
    private var backgroundFill: Color {
        if canDrag { return Theme.backgroundCardActive }
        if isDropTargeted || isHovered { return Theme.backgroundCardHover }
        return Theme.backgroundCard
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: PanelDimensions.folderCardCornerRadius)
            .stroke(borderColor, lineWidth: isDropTargeted ? 1.5 : 1)
    }
    
    private var borderColor: Color {
        isHovered || isDropTargeted ? Theme.borderHover : Theme.border
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
            // Use .common run loop mode for reliable timer firing
            holdTimer = Timer(timeInterval: holdDuration, repeats: false) { _ in
                DispatchQueue.main.async {
                    canDrag = true
                    isWiggling = true
                    onDragStarted()
                }
            }
            RunLoop.current.add(holdTimer!, forMode: .common)
        }
        
        if canDrag {
            dragOffset = value.translation
            onDragChanged(value.translation)
        }
    }
    
    private func handleDragEnded() {
        invalidateTimer()
        
        if !canDrag {
            onTap()
        } else {
            isWiggling = false
            onDragEnded()
        }
        
        // Snap back instantly - no animation
        // The list handles positioning folders in their new locations
        dragOffset = .zero
        canDrag = false
    }
    
    // MARK: - Thumbnails
    
    private func loadThumbnails() {
        let imagesToLoad = Array(folder.sortedImages.prefix(4))
        
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = imagesToLoad.compactMap { image in
                FileManagerHelper.loadThumbnail(filename: image.filename)
            }
            DispatchQueue.main.async {
                self.thumbnails = loaded
            }
        }
    }
    
    // MARK: - Image Saving
    
    private func saveImage(_ data: Data, name: String) {
        do {
            let filename = try FileManagerHelper.saveImage(data, originalName: name)
            let newImage = DesignImage(
                filename: filename,
                originalName: name,
                sortOrder: folder.images.count,
                folder: folder
            )
            modelContext.insert(newImage)
            showSuccessPulse = true
        } catch {
            Logger.error("Failed to save image", error: error)
        }
    }
    
    // MARK: - Paste Handling
    
    private func pasteFromClipboard() {
        guard let imageData = clipboardWatcher.getImageData() else { return }
        saveImage(imageData, name: "Pasted Image")
    }
    
    // MARK: - Drop Handling
    
    private func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in
                    guard let data = data else { return }
                    
                    DispatchQueue.main.async {
                        saveImage(data, name: "Dropped Image")
                    }
                }
                return true
            }
        }
        return false
    }
}

// MARK: - Preview

#Preview {
    let folder = DesignFolder(name: "Test Folder")
    return FolderCard(
        folder: folder,
        onTap: { },
        onDragStarted: { },
        onDragChanged: { _ in },
        onDragEnded: { }
    )
    .environment(ClipboardWatcher())
    .modelContainer(for: [DesignFolder.self, DesignImage.self])
    .padding()
    .background(Theme.backgroundSolid)
}
