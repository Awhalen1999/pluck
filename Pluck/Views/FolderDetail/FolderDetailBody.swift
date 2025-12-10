//
//  FolderDetailBody.swift
//  Pluck
//
//  Created by Alex Whalen on 2025-12-10.
//

import SwiftUI
import SwiftData

/// Implementation of folder detail view with image grid and drop handling
struct FolderDetailBody: View {
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
    
    // MARK: - Header Bar
    
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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
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
            .padding(.horizontal, 8)
            .padding(.vertical, PanelDimensions.contentPadding - 2)
        }
    }
    
    // MARK: - Drop Handling
    
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
