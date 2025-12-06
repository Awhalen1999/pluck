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
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { windowManager.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                
                Circle()
                    .fill(Color(hex: folder.colorHex) ?? .purple)
                    .frame(width: 8, height: 8)
                    .padding(.leading, 8)
                
                Text(folder.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(action: { windowManager.collapse() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Image grid
            if folder.images.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Drop images here")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(folder.images.sorted(by: { $0.sortOrder < $1.sortOrder })) { image in
                            ThumbnailView(image: image)
                                .onTapGesture {
                                    windowManager.focusImage(image)
                                }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
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

struct ThumbnailView: View {
    let image: DesignImage
    @State private var thumbnail: NSImage?
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 75, height: 75)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 75, height: 75)
            }
        }
        .cornerRadius(6)
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = FileManagerHelper.loadThumbnail(filename: image.filename)
            DispatchQueue.main.async {
                self.thumbnail = loaded
            }
        }
    }
}

#Preview {
    let folder = DesignFolder(name: "Test Folder")
    return FolderDetailView(folder: folder)
        .environment(WindowManager())
        .modelContainer(for: [DesignFolder.self, DesignImage.self])
        .frame(width: 280, height: 350)
}
