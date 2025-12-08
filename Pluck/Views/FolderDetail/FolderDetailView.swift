//
//  FolderDetailView.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct FolderDetailView: View {
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
                header
                content
            }
            .dropTarget(
                isTargeted: $isDropTargeted,
                cornerRadius: PanelDimensions.expandedCornerRadius,
                accentColor: Color(hex: folder.colorHex)
            ) { providers in
                handleDrop(providers)
            }
            
            // Paste hint overlay
            PasteOverlay(isVisible: clipboardWatcher.hasImage)
        }
        .onAppear { registerPasteHandler() }
        .onDisappear { unregisterPasteHandler() }
    }
    
    // MARK: - Paste Registration
    
    private func registerPasteHandler() {
        FloatingPanelController.shared.onPasteCommand = { [self] in
            handlePaste()
        }
    }
    
    private func unregisterPasteHandler() {
        FloatingPanelController.shared.onPasteCommand = nil
    }
    
    // MARK: - Header
    
    private var header: some View {
        PanelHeader(
            title: folder.name,
            showBackButton: true,
            accentColor: Color(hex: folder.colorHex),
            onBack: { windowManager.goBack() },
            onClose: { windowManager.collapse() }
        )
    }
    
    // MARK: - Content
    
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
                .foregroundStyle(.white.opacity(0.2))
            
            Text("Drop images here")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.3))
            
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
    
    // MARK: - Paste Handling
    
    @discardableResult
    private func handlePaste() -> Bool {
        guard let imageData = clipboardWatcher.getImageData() else { return false }
        saveImage(imageData, name: "Pasted Image")
        return true
    }
    
    // MARK: - Drop Handling
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
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

// MARK: - Preview

#Preview {
    let folder = DesignFolder(name: "Test Folder")
    return FolderDetailView(folder: folder)
        .environment(WindowManager())
        .environment(ClipboardWatcher())
        .modelContainer(for: [DesignFolder.self, DesignImage.self])
        .frame(width: 220, height: 350)
        .background(Color.black.opacity(0.8))
}
