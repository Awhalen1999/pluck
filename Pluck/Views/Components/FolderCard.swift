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
    @Environment(PasteController.self) private var pasteController
    
    @State private var isHovered = false
    @State private var isDropTargeted = false
    @State private var thumbnails: [NSImage] = []
    
    // Drag state
    @State private var holdTimer: Timer?
    @State private var canDrag = false
    @State private var dragOffset: CGSize = .zero
    
    // MARK: - Constants
    
    private let cardHeight: CGFloat = 68
    private let cardCornerRadius: CGFloat = 10
    private let holdDuration: TimeInterval = 0.5
    
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
            .offset(dragOffset)
            .scaleEffect(canDrag ? 1.02 : 1.0)
            .shadow(color: canDrag ? .black.opacity(0.3) : .clear, radius: canDrag ? 12 : 0, y: canDrag ? 6 : 0)
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
        .onChange(of: folder.images.count) { _, _ in
            loadThumbnails()
        }
    }
    
    private var titleRow: some View {
        HStack {
            Text(folder.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Spacer()
            
            if showPasteBadge {
                PasteBadge {
                    pasteToFolder()
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(folder.imageCount)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .animation(.easeOut(duration: 0.15), value: showPasteBadge)
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
            .foregroundStyle(.white.opacity(0.4))
        } else {
            ThumbnailStack(
                thumbnails: thumbnails,
                totalCount: folder.imageCount
            )
        }
    }
    
    // MARK: - Styling
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius)
            .fill(backgroundFill)
    }
    
    private var backgroundFill: Color {
        if canDrag { return .white.opacity(0.15) }
        if isDropTargeted || isHovered { return .white.opacity(0.1) }
        return .white.opacity(0.05)
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius)
            .stroke(borderColor, lineWidth: isDropTargeted ? 1.5 : 1)
    }
    
    private var borderColor: Color {
        if isDropTargeted { return folderColor }
        if isHovered { return .white.opacity(0.2) }
        return .white.opacity(0.1)
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
        _ = pasteController.pasteToFolder(folder, modelContext: modelContext)
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
        } catch {
            print("Failed to save image: \(error)")
        }
    }
}
