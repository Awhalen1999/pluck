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
    @State private var isDropTargeted = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            // Content
            if folder.images.isEmpty {
                emptyState
            } else {
                imageGrid
            }
        }
        .overlay(dropOverlay)
        .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 8) {
            Button(action: { windowManager.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            
            Circle()
                .fill(Color(hex: folder.colorHex) ?? .purple)
                .frame(width: 8, height: 8)
            
            Text(folder.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
            
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
    
    // MARK: - Empty State
    
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
    
    // MARK: - Image Grid
    
    private var imageGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(folder.images.sorted(by: { $0.sortOrder < $1.sortOrder })) { image in
                    ThumbnailView(image: image)
                        .onTapGesture {
                            windowManager.focusImage(image)
                        }
                }
            }
            .padding(10)
        }
    }
    
    // MARK: - Drop Overlay
    
    private var dropOverlay: some View {
        Group {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.05))
                    )
                    .padding(4)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
    }
    
    // MARK: - Drop Handling
    
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

// MARK: - Thumbnail View

struct ThumbnailView: View {
    let image: DesignImage
    @State private var thumbnail: NSImage?
    @State private var isHovered = false
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.white.opacity(0.05))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                            .tint(.white.opacity(0.3))
                    )
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = FileManagerHelper.loadThumbnail(filename: image.filename)
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.2)) {
                    self.thumbnail = loaded
                }
            }
        }
    }
}

#Preview {
    let folder = DesignFolder(name: "Test Folder")
    return FolderDetailView(folder: folder)
        .environment(WindowManager())
        .modelContainer(for: [DesignFolder.self, DesignImage.self])
        .frame(width: 220, height: 300)
        .background(Color.black.opacity(0.8))
}
