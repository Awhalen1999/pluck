//
//  FolderListView.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct FolderListView: View {
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DesignFolder.sortOrder) private var folders: [DesignFolder]
    
    @State private var isAddingFolder = false
    @State private var newFolderName = ""
    @State private var selectedColorIndex = 0
    @FocusState private var isTextFieldFocused: Bool
    
    private let colorOptions = [
        "#8B5CF6", // Purple
        "#3B82F6", // Blue
        "#10B981", // Green
        "#F59E0B", // Amber
        "#EF4444", // Red
        "#EC4899", // Pink
        "#6366F1", // Indigo
        "#14B8A6", // Teal
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            // Folder list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(folders) { folder in
                        BoxCardView(folder: folder)
                    }
                    
                    // New folder
                    newFolderCard
                }
                .padding(12)
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("Folders")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
            
            Button(action: { windowManager.collapse() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - New Folder Card
    
    private var newFolderCard: some View {
        Group {
            if isAddingFolder {
                HStack(spacing: 10) {
                    // Color dot - tap to cycle
                    Circle()
                        .fill(Color(hex: colorOptions[selectedColorIndex]) ?? .purple)
                        .frame(width: 10, height: 10)
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.15)) {
                                selectedColorIndex = (selectedColorIndex + 1) % colorOptions.count
                            }
                        }
                    
                    // Name field
                    TextField("Folder name", text: $newFolderName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .focused($isTextFieldFocused)
                        .onSubmit { createFolder() }
                        .onExitCommand { cancelAddFolder() }
                    
                    Spacer()
                    
                    // Confirm button
                    Button(action: { createFolder() }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
                .onAppear {
                    isTextFieldFocused = true
                }
            } else {
                Button(action: { withAnimation(.easeOut(duration: 0.15)) { isAddingFolder = true } }) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text("New Folder")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Actions
    
    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            cancelAddFolder()
            return
        }
        
        let folder = DesignFolder(name: name, sortOrder: folders.count)
        folder.colorHex = colorOptions[selectedColorIndex]
        modelContext.insert(folder)
        
        withAnimation(.easeOut(duration: 0.15)) {
            newFolderName = ""
            selectedColorIndex = 0
            isAddingFolder = false
        }
    }
    
    private func cancelAddFolder() {
        withAnimation(.easeOut(duration: 0.15)) {
            newFolderName = ""
            selectedColorIndex = 0
            isAddingFolder = false
        }
    }
}

// MARK: - Box Card View

struct BoxCardView: View {
    let folder: DesignFolder
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var isHovered = false
    @State private var isDropTargeted = false
    @State private var thumbnails: [NSImage] = []
    
    private var folderColor: Color {
        Color(hex: folder.colorHex) ?? .purple
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Color accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(folderColor)
                .frame(width: 4)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Title row
                HStack {
                    Text(folder.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(folder.imageCount) item\(folder.imageCount == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                // Thumbnail row or empty state
                if folder.images.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.2))
                        
                        Text("Drop images here")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                } else {
                    // Thumbnail preview row
                    HStack(spacing: -8) {
                        ForEach(Array(thumbnails.prefix(4).enumerated()), id: \.offset) { index, image in
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.black.opacity(0.5), lineWidth: 1)
                                )
                                .zIndex(Double(4 - index))
                        }
                        
                        if folder.imageCount > 4 {
                            Text("+\(folder.imageCount - 4)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.leading, 12)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(isDropTargeted ? 0.12 : (isHovered ? 0.08 : 0.05)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isDropTargeted ? folderColor.opacity(0.8) : .white.opacity(isHovered ? 0.12 : 0.06),
                    lineWidth: isDropTargeted ? 1.5 : 1
                )
        )
        .scaleEffect(isDropTargeted ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
        .onHover { hovering in
            isHovered = hovering
        }
        .contentShape(Rectangle())
        .onTapGesture {
            windowManager.openFolder(folder)
        }
        .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .onAppear {
            loadThumbnails()
        }
        .onChange(of: folder.images.count) { _, _ in
            loadThumbnails()
        }
    }
    
    private func loadThumbnails() {
        let sortedImages = folder.images.sorted { $0.sortOrder < $1.sortOrder }
        let imagesToLoad = Array(sortedImages.prefix(4))
        
        DispatchQueue.global(qos: .userInitiated).async {
            var loaded: [NSImage] = []
            for image in imagesToLoad {
                if let thumb = FileManagerHelper.loadThumbnail(filename: image.filename) {
                    loaded.append(thumb)
                }
            }
            DispatchQueue.main.async {
                self.thumbnails = loaded
            }
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                    guard let data = data else { return }
                    
                    DispatchQueue.main.async {
                        if let filename = FileManagerHelper.saveImage(data, originalName: "Dropped Image") {
                            let newImage = DesignImage(
                                filename: filename,
                                originalName: "Dropped Image",
                                sortOrder: folder.images.count,
                                folder: folder
                            )
                            modelContext.insert(newImage)
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

#Preview {
    FolderListView()
        .environment(WindowManager())
        .modelContainer(for: [DesignFolder.self, DesignImage.self])
        .frame(width: 220, height: 350)
        .background(Color.black.opacity(0.8))
}
