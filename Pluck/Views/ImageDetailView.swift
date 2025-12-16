//
//  ImageDetailView.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct ImageDetailView: View {
    let image: DesignImage
    let onBack: () -> Void
    let onDelete: () -> Void
    
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var isBackHovered = false
    @State private var loadedImage: NSImage?
    
    // Edit mode
    @State private var isEditing = false
    @State private var editedName: String = ""
    @FocusState private var isNameFocused: Bool
    
    private var popoutManager: PopoutWindowManager { PopoutWindowManager.shared }
    
    private var isPopoutOpen: Bool {
        popoutManager.isImageOpen(image.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            imageContent
        }
        .onAppear { loadFullImage() }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 2) {
            // Back button
            IconButton(
                icon: "chevron.left",
                action: { isEditing ? cancelEdit() : onBack() },
                isInactive: !windowManager.isWindowActive
            )
            
            // Image name
            if isEditing {
                TextField("Image name", text: $editedName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .focused($isNameFocused)
                    .onSubmit { saveEdit() }
            } else {
                Text(image.originalName)
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
            IconButton(
                icon: isPopoutOpen ? "pin.fill" : "arrow.up.forward.square",
                action: { isPopoutOpen ? closePopout() : popoutImage() },
                isInactive: !windowManager.isWindowActive
            )
            IconButton(icon: "pencil", action: startEdit, isInactive: !windowManager.isWindowActive)
            IconButton(icon: "xmark", action: { windowManager.close() }, isInactive: !windowManager.isWindowActive)
        }
    }
    
    // MARK: - Edit Mode Buttons
    
    private var editModeButtons: some View {
        HStack(spacing: Theme.Spacing.xs) {
            IconButton(icon: "trash", action: deleteImage, isDestructive: true, isInactive: !windowManager.isWindowActive)
            IconButton(icon: "checkmark", action: saveEdit, isInactive: !windowManager.isWindowActive)
        }
    }
    
    // MARK: - Edit Actions
    
    private func startEdit() {
        editedName = image.originalName
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
        
        image.originalName = trimmedName
        try? modelContext.save()
        
        isEditing = false
        isNameFocused = false
    }
    
    private func deleteImage() {
        FileManagerHelper.deleteImage(filename: image.filename)
        modelContext.delete(image)
        try? modelContext.save()
        onDelete()
    }
    
    private func popoutImage() {
        guard !isPopoutOpen else { return }
        PopoutWindowManager.shared.openImage(image)
    }
    
    private func closePopout() {
        PopoutWindowManager.shared.closeImage(image.id)
    }
    
    // MARK: - Image Content
    
    private var imageContent: some View {
        GeometryReader { geo in
            if let loadedImage {
                Image(nsImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(Theme.Spacing.sm)
            } else {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Image Loading
    
    private func loadFullImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let nsImage = FileManagerHelper.loadImage(filename: image.filename) {
                DispatchQueue.main.async {
                    self.loadedImage = nsImage
                }
            }
        }
    }
}
