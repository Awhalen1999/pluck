//
//  FolderCard.swift
//  Pluck
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct FolderCard: View {
    let folder: DesignFolder
    let onTap: () -> Void
    let onDragStarted: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Environment(PasteController.self) private var pasteController
    
    @State private var isHovered = false
    @State private var isDropTargeted = false
    @State private var thumbnails: [NSImage] = []
    @State private var shouldPulse = false
    @State private var thumbnailRefreshID = UUID()  // Force refresh trigger
    
    // Drag state
    @State private var holdTimer: Timer?
    @State private var canDrag = false
    @State private var dragOffset: CGSize = .zero
    
    // MARK: - Constants
    
    private let cardHeight: CGFloat = 68
    
    private var folderColor: Color {
        Color(hex: folder.colorHex) ?? .purple
    }
    
    private var showPasteBadge: Bool {
        isHovered && pasteController.canShowPasteUI && !canDrag
    }
    
    var body: some View {
        cardContent
            .frame(height: cardHeight)
            .wiggle(when: $canDrag)
            .pulse(on: $shouldPulse)
            .offset(dragOffset)
            .scaleEffect(canDrag ? 1.02 : 1.0)
            .shadow(
                color: canDrag ? Theme.shadowHeavy : .clear,
                radius: canDrag ? 12 : 0,
                y: canDrag ? 4 : 0
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: canDrag)
            .animation(.easeOut(duration: 0.15), value: isDropTargeted)
            .gesture(dragGesture)
            .onDrop(of: [.item], delegate: ImageDropWatcher(
                isTargeted: $isDropTargeted,
                onDrop: { providers in
                    handleImageDrop(providers)
                },
                onSuccess: {
                    shouldPulse = true
                }
            ))
            .onDisappear {
                invalidateTimer()
            }
    }
    
    // MARK: - Card Content
    
    private var cardContent: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(folderColor)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 6) {
                titleRow
                thumbnailRow
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(cardBackground)
        .overlay(cardBorder)
        .onHover { isHovered = $0 }
        .onAppear { loadThumbnails() }
        .onChange(of: folder.images.count) { _, _ in
            loadThumbnails()
        }
        .onChange(of: thumbnailRefreshID) { _, _ in
            loadThumbnails()
        }
        .onChange(of: pasteController.lastPastedFolderID) { _, newID in
            if newID == folder.id {
                shouldPulse = true
                // Refresh thumbnails when paste completes
                refreshThumbnails()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    pasteController.lastPastedFolderID = nil
                }
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
            
            if isDropTargeted {
                DropBadge()
                    .transition(.scale.combined(with: .opacity))
            } else if showPasteBadge {
                PasteBadge {
                    pasteToFolder()
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(folder.imageCount)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .animation(.easeOut(duration: 0.15), value: showPasteBadge)
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
    }
    
    @ViewBuilder
    private var thumbnailRow: some View {
        if folder.images.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 10))
                Text("Drop images here")
                    .font(.system(size: 10))
            }
            .foregroundStyle(Theme.textTertiary)
        } else {
            ThumbnailStack(
                thumbnails: thumbnails,
                totalCount: folder.imageCount
            )
        }
    }
    
    // MARK: - Styling
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.medium)
            .fill(backgroundFill)
            .shadow(color: Theme.shadowLight, radius: 2, y: 1)
    }
    
    private var backgroundFill: Color {
        if canDrag { return Theme.cardBackgroundActive }
        if isDropTargeted || isHovered { return Theme.cardBackgroundHover }
        return Theme.cardBackground
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.medium)
            .stroke(borderColor, lineWidth: 1)
    }
    
    private var borderColor: Color {
        if isDropTargeted { return Theme.accent.opacity(0.5) }
        if isHovered { return Theme.borderHover }
        return Theme.border
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
        let holdDuration: TimeInterval = 0.5
        
        if holdTimer == nil && !canDrag {
            holdTimer = Timer(timeInterval: holdDuration, repeats: false) { _ in
                DispatchQueue.main.async {
                    canDrag = true
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
            onDragEnded()
        }
        
        dragOffset = .zero
        canDrag = false
    }
    
    // MARK: - Thumbnails
    
    private func refreshThumbnails() {
        // Small delay to allow SwiftData to settle, then force refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            thumbnailRefreshID = UUID()
        }
    }
    
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
    
    // MARK: - Paste Handling
    
    private func pasteToFolder() {
        if pasteController.pasteToFolder(folder, modelContext: modelContext) {
            shouldPulse = true
            refreshThumbnails()
        }
    }
    
    // MARK: - Drop Handling
    
    private func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // Try file URL first (handles SVG and other files)
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    
                    DispatchQueue.main.async {
                        saveImageFromURL(url)
                    }
                }
                return true
            }
            
            // Try SVG specifically
            if provider.hasItemConformingToTypeIdentifier(UTType.svg.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.svg.identifier) { data, error in
                    guard let data = data else { return }
                    
                    DispatchQueue.main.async {
                        saveImage(data, name: "Dropped Image", fileExtension: "svg")
                    }
                }
                return true
            }
            
            // Try generic image data (PNG, JPEG, etc.)
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    guard let data = data else { return }
                    
                    DispatchQueue.main.async {
                        saveImage(data, name: "Dropped Image", fileExtension: nil)
                    }
                }
                return true
            }
        }
        return false
    }
    
    private func saveImageFromURL(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        guard FileManagerHelper.supportedImageExtensions.contains(ext) else { return }
        
        do {
            let filename = try FileManagerHelper.saveImageFromURL(url, originalName: url.lastPathComponent)
            let newImage = DesignImage(
                filename: filename,
                originalName: url.deletingPathExtension().lastPathComponent,
                sortOrder: folder.images.count,
                folder: folder
            )
            modelContext.insert(newImage)
            shouldPulse = true
            refreshThumbnails()  // Force thumbnail refresh after drop
        } catch {
            Log.error("Failed to save image from URL", error: error, subsystem: .drop)
        }
    }
    
    private func saveImage(_ data: Data, name: String, fileExtension: String?) {
        do {
            let filename = try FileManagerHelper.saveImage(data, originalName: name, fileExtension: fileExtension)
            let newImage = DesignImage(
                filename: filename,
                originalName: name,
                sortOrder: folder.images.count,
                folder: folder
            )
            modelContext.insert(newImage)
            shouldPulse = true
            refreshThumbnails()  // Force thumbnail refresh after drop
        } catch {
            Log.error("Failed to save image", error: error, subsystem: .drop)
        }
    }
}
