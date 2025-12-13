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
    @State private var isCloseHovered = false
    @State private var isEditHovered = false
    @State private var isPopoutHovered = false
    @State private var loadedImage: NSImage?
    
    // Edit mode
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var isDeleteHovered = false
    @State private var isSaveHovered = false
    @FocusState private var isNameFocused: Bool
    
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
            // Back button (cancels edit if editing)
            Button(action: { isEditing ? cancelEdit() : onBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isBackHovered ? .white : .white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isBackHovered ? .white.opacity(0.1) : .clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isBackHovered = $0 }
            
            // Image name (editable in edit mode)
            if isEditing {
                TextField("Image name", text: $editedName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .focused($isNameFocused)
                    .onSubmit { saveEdit() }
            } else {
                Text(image.originalName)
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
            // Popout button
            Button(action: { popoutImage() }) {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isPopoutHovered ? .white : .white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isPopoutHovered ? .white.opacity(0.1) : .clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isPopoutHovered = $0 }
            
            // Edit button
            Button(action: { startEdit() }) {
                Image(systemName: "pencil")
                    .font(.system(size: 10, weight: .medium))
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
                    .font(.system(size: 10, weight: .medium))
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
            Button(action: { deleteImage() }) {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .medium))
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
                    .font(.system(size: 10, weight: .bold))
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
        // Delete the file
        FileManagerHelper.deleteImage(filename: image.filename)
        
        // Delete from database
        modelContext.delete(image)
        try? modelContext.save()
        
        onDelete()
    }
    
    private func popoutImage() {
        PopoutWindowManager.shared.openImage(image)
    }
    
    // MARK: - Image Content
    
    private var imageContent: some View {
        GeometryReader { geo in
            if let loadedImage {
                Image(nsImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
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
