//
//  FolderDetailView.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct FolderDetailView: View {
    let folder: DesignFolder
    let onBack: () -> Void
    let onSelectImage: (DesignImage) -> Void
    let onDelete: () -> Void
    
    @Environment(WindowManager.self) private var windowManager
    @Environment(PasteController.self) private var pasteController
    @Environment(\.modelContext) private var modelContext
    
    @State private var isBackHovered = false
    @State private var isCloseHovered = false
    @State private var isEditHovered = false
    @State private var isDropTargeted = false
    @State private var shouldPulse = false
    
    // Edit mode
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedColorIndex: Int = 0
    @State private var isDeleteHovered = false
    @State private var isSaveHovered = false
    @FocusState private var isNameFocused: Bool
    
    // MARK: - Constants
    
    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]
    private let thumbnailSize: CGFloat = 58
    private let thumbnailCornerRadius: CGFloat = 8
    
    private var folderColor: Color {
        if isEditing {
            return Color(hex: FolderColors.all[editedColorIndex]) ?? .purple
        }
        return Color(hex: folder.colorHex) ?? .purple
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .pulse(on: $shouldPulse)
        .onDrop(of: ["public.image", "public.file-url"], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .onChange(of: pasteController.lastPastedFolderID) { _, newID in
            if newID == folder.id {
                shouldPulse = true
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 2) {
            // Back button (cancels edit if editing)
            Button(action: { isEditing ? cancelEdit() : onBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isBackHovered ? .white : .white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isBackHovered ? .white.opacity(0.1) : .clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isBackHovered = $0 }
            
            // Color dot (tappable in edit mode)
            Circle()
                .fill(folderColor)
                .frame(width: 8, height: 8)
                .onTapGesture {
                    if isEditing {
                        cycleColor()
                    }
                }
                .padding(.trailing, 4)
                .animation(.easeOut(duration: 0.15), value: editedColorIndex)
            
            // Folder name (editable in edit mode)
            if isEditing {
                TextField("Folder name", text: $editedName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .focused($isNameFocused)
                    .onSubmit { saveEdit() }
            } else {
                Text(folder.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Action buttons
            if isEditing {
                editModeButtons
            } else {
                normalModeButtons
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }
    
    // MARK: - Normal Mode Buttons
    
    private var normalModeButtons: some View {
        HStack(spacing: 4) {
            // Edit button
            Button(action: { startEdit() }) {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isEditHovered ? .white : .white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isEditHovered ? .white.opacity(0.1) : .clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isEditHovered = $0 }
           
            
            // Close button
            Button(action: { windowManager.close() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isCloseHovered ? .white : .white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isCloseHovered ? .white.opacity(0.1) : .clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isCloseHovered = $0 }
        }
    }
    
    // MARK: - Edit Mode Buttons
    
    private var editModeButtons: some View {
        HStack(spacing: 4) {
            // Delete button
            Button(action: { deleteFolder() }) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isDeleteHovered ? .red : .white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isDeleteHovered ? .red.opacity(0.15) : .clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isDeleteHovered = $0 }
            
            // Save button
            Button(action: { saveEdit() }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSaveHovered ? .white : .white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSaveHovered ? .white.opacity(0.1) : .clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isSaveHovered = $0 }
        }
    }
    
    // MARK: - Edit Actions
    
    private func startEdit() {
        editedName = folder.name
        editedColorIndex = FolderColors.all.firstIndex(of: folder.colorHex) ?? 0
        isEditing = true
        isNameFocused = true
    }
    
    private func cancelEdit() {
        isEditing = false
        isNameFocused = false
    }
    
    private func saveEdit() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            cancelEdit()
            return
        }
        
        folder.name = trimmedName
        folder.colorHex = FolderColors.all[editedColorIndex]
        try? modelContext.save()
        
        isEditing = false
        isNameFocused = false
    }
    
    private func cycleColor() {
        editedColorIndex = (editedColorIndex + 1) % FolderColors.all.count
    }
    
    private func deleteFolder() {
        modelContext.delete(folder)
        try? modelContext.save()
        onDelete()
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
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("Drop images here")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
            
            if pasteController.canShowPasteUI {
                PasteBadge {
                    pasteToFolder()
                }
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(isDropTargeted ? Color.white.opacity(0.05) : .clear)
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
    }
    
    // MARK: - Image Grid
    
    private var imageGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(folder.sortedImages) { image in
                    ImageThumbnail(
                        image: image,
                        size: thumbnailSize,
                        cornerRadius: thumbnailCornerRadius,
                        onTap: { onSelectImage(image) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(isDropTargeted ? Color.white.opacity(0.03) : .clear)
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
    }
    
    // MARK: - Paste Handling
    
    private func pasteToFolder() {
        if pasteController.pasteToFolder(folder, modelContext: modelContext) {
            shouldPulse = true
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
            shouldPulse = true
        } catch {
            print("Failed to save image: \(error)")
        }
    }
}

// MARK: - Image Thumbnail

struct ImageThumbnail: View {
    let image: DesignImage
    let size: CGFloat
    let cornerRadius: CGFloat
    let onTap: () -> Void
    
    @State private var thumbnail: NSImage?
    @State private var isHovered = false
    
    var body: some View {
        thumbnailContent
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isHovered ? .white.opacity(0.3) : .white.opacity(0.1), lineWidth: 1)
            )
            .onHover { isHovered = $0 }
            .onTapGesture { onTap() }
            .onAppear { loadThumbnail() }
    }
    
    private var thumbnailContent: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.white.opacity(0.05))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            }
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let loaded = FileManagerHelper.loadThumbnail(filename: image.filename) {
                DispatchQueue.main.async {
                    self.thumbnail = loaded
                }
            }
        }
    }
}
