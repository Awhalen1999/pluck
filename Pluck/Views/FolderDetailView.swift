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
            // Back button (now using IconButton)
            IconButton(
                icon: "chevron.left",
                action: { isEditing ? cancelEdit() : onBack() },
                isInactive: !windowManager.isWindowActive
            )
            
            // Color dot
            Circle()
                .fill(folderColor)
                .frame(width: 8, height: 8)
                .onTapGesture {
                    if isEditing { cycleColor() }
                }
                .padding(.trailing, 4)
                .animation(.easeOut(duration: 0.15), value: editedColorIndex)
            
            // Folder name
            if isEditing {
                TextField("Folder name", text: $editedName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .focused($isNameFocused)
                    .onSubmit { saveEdit() }
            } else {
                Text(folder.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isEditing {
                editModeButtons
            } else {
                normalModeButtons
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xs)
    }
    
    // MARK: - Normal Mode Buttons
    
    private var normalModeButtons: some View {
        HStack(spacing: Theme.Spacing.xs) {
            IconButton(icon: "pencil", action: startEdit, isInactive: !windowManager.isWindowActive)
            IconButton(icon: "xmark", action: { windowManager.close() }, isInactive: !windowManager.isWindowActive)
        }
    }
    
    // MARK: - Edit Mode Buttons
    
    private var editModeButtons: some View {
        HStack(spacing: Theme.Spacing.xs) {
            IconButton(icon: "trash", action: deleteFolder, isDestructive: true, isInactive: !windowManager.isWindowActive)
            IconButton(icon: "checkmark", action: saveEdit, isInactive: !windowManager.isWindowActive)
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
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 28))
                .foregroundStyle(Theme.textTertiary)
            
            Text("Drop images here")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
            
            if pasteController.canShowPasteUI {
                PasteBadge {
                    pasteToFolder()
                }
                .padding(.top, Theme.Spacing.xs)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(isDropTargeted ? Theme.cardBackground : .clear)
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
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(isDropTargeted ? Theme.cardBackground.opacity(0.5) : .clear)
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
    @State private var isPinHovered = false
    
    private var popoutManager: PopoutWindowManager { PopoutWindowManager.shared }
    
    private var isPopoutOpen: Bool {
        popoutManager.isImageOpen(image.id)
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            thumbnailContent
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(isHovered ? Theme.borderActive : Theme.border, lineWidth: 1)
                )
                .shadow(color: Theme.shadowLight, radius: 2, y: 1)
            
            if isPopoutOpen {
                PopoutIndicator(isHovered: isPinHovered)
                    .onHover { isPinHovered = $0 }
                    .onTapGesture { closePopout() }
                    .padding(4)
            }
        }
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
        .onAppear { loadThumbnail() }
    }
    
    private func closePopout() {
        PopoutWindowManager.shared.closeImage(image.id)
    }
    
    private var thumbnailContent: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Theme.cardBackground)
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

// MARK: - Popout Indicator

struct PopoutIndicator: View {
    var isHovered: Bool = false
    
    var body: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(isHovered ? Theme.textPrimary : Theme.textSecondary)
            .frame(width: 16, height: 16)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Theme.cardBackgroundActive : Theme.cardBackground)
                    .shadow(color: Theme.shadowLight, radius: 1, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.border, lineWidth: 0.5)
            )
            .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
