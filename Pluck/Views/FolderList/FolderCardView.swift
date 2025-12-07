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
    
    @State private var isHovered = false
    @State private var isDropTargeted = false
    @State private var thumbnails: [NSImage] = []
    
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
        isHovered && clipboardWatcher.hasImage
    }
    
    var body: some View {
        cardContent
            .frame(height: PanelDimensions.folderCardHeight)
            .offset(dragOffset)
            .scaleEffect(canDrag ? 1.02 : 1.0)
            .shadow(color: .black.opacity(canDrag ? 0.4 : 0), radius: canDrag ? 12 : 0, y: canDrag ? 6 : 0)
            .wiggle(when: $isWiggling, angle: 1.5)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: canDrag)
            .animation(.easeOut(duration: 0.15), value: isDropTargeted)
            .gesture(dragGesture)
            .onDrop(of: ["public.image", "public.file-url"], isTargeted: $isDropTargeted) { providers in
                handleImageDrop(providers)
            }
    }
    
    // MARK: - Card Content
    
    private var cardContent: some View {
        HStack(spacing: 12) {
            // Color accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(folderColor)
                .frame(width: 4)
            
            // Content
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
        .onChange(of: folder.images.count) { _, _ in
            loadThumbnails()
        }
    }
    
    private var titleRow: some View {
        HStack {
            Text(folder.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
            
            Spacer()
            
            if showPasteBadge {
                PasteBadge()
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else {
                Text("\(folder.imageCount) item\(folder.imageCount == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .animation(.easeOut(duration: 0.15), value: showPasteBadge)
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
        if isDropTargeted { return 0.1 }
        if isHovered { return 0.08 }
        return 0.05
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: PanelDimensions.folderCardCornerRadius)
            .stroke(borderColor, lineWidth: isDropTargeted ? 1.5 : 1)
    }
    
    private var borderColor: Color {
        if isDropTargeted { return folderColor }
        return .white.opacity(isHovered ? 0.12 : 0.06)
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
        // Start hold timer if not already dragging
        if holdTimer == nil && !canDrag {
            holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { _ in
                DispatchQueue.main.async {
                    canDrag = true
                    isWiggling = true
                    onDragStarted()
                }
            }
        }
        
        // Update drag offset if dragging
        if canDrag {
            dragOffset = value.translation
            onDragChanged(value.translation)
        }
    }
    
    private func handleDragEnded() {
        holdTimer?.invalidate()
        holdTimer = nil
        
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
    
    // MARK: - Drop Handling
    
    private func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in
                    guard let data = data else { return }
                    
                    DispatchQueue.main.async {
                        saveDroppedImage(data)
                    }
                }
                return true
            }
        }
        return false
    }
    
    private func saveDroppedImage(_ data: Data) {
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
            print("Failed to save dropped image: \(error)")
        }
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
    .modelContainer(for: [DesignFolder.self, DesignImage.self])
    .padding()
    .background(Color.black.opacity(0.8))
}
