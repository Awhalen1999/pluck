//
//  FolderCardView.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct FolderCardView: View {
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
            .shadow(color: .black.opacity(canDrag ? 0.4 : 0), radius: canDrag ? 12 : 0, y: canDrag ? 6 : 0)
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
                .foregroundStyle(.white.opacity(0.9))
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
                    .foregroundStyle(.white.opacity(0.4))
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
            .fill(.white.opacity(backgroundOpacity))
    }
    
    private var backgroundOpacity: Double {
        if canDrag { return 0.12 }
        if isDropTargeted || isHovered { return 0.08 }
        return 0.05
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: PanelDimensions.folderCardCornerRadius)
            .stroke(borderColor, lineWidth: isDropTargeted ? 1.5 : 1)
    }
    
    private var borderColor: Color {
        .white.opacity(isHovered || isDropTargeted ? 0.12 : 0.06)
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
            holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { _ in
                DispatchQueue.main.async {
                    canDrag = true
                    isWiggling = true
                    onDragStarted()
                }
            }
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
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            dragOffset = .zero
            canDrag = false
        }
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
            print("Failed to save image: \(error)")
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
    return FolderCardView(
        folder: folder,
        onTap: { },
        onDragStarted: { },
        onDragChanged: { _ in },
        onDragEnded: { }
    )
    .environment(ClipboardWatcher())
    .modelContainer(for: [DesignFolder.self, DesignImage.self])
    .padding()
    .background(Color.black.opacity(0.8))
}
