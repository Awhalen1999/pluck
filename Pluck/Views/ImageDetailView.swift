//
//  ImageDetailView.swift
//  Pluck
//

import SwiftUI

struct ImageDetailView: View {
    let image: DesignImage
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var fullImage: NSImage?
    @State private var isHoveringDelete = false
    
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
                
                Text(image.originalName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.leading, 8)
                
                Spacer()
                
                // Delete button
                Button(action: { deleteImage() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(isHoveringDelete ? .red : .white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringDelete = hovering
                }
                .padding(.trailing, 8)
                
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
            
            // Full image
            if let fullImage = fullImage {
                Image(nsImage: fullImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(12)
                    .onDrag {
                        NSItemProvider(object: fullImage)
                    }
            } else {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            }
            
            // Source URL if available
            if let sourceURL = image.sourceURL, !sourceURL.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack {
                    Image(systemName: "link")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Text(sourceURL)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: { copySourceURL() }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .onAppear {
            loadFullImage()
        }
    }
    
    private func loadFullImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = FileManagerHelper.loadImage(filename: image.filename)
            DispatchQueue.main.async {
                self.fullImage = loaded
            }
        }
    }
    
    private func deleteImage() {
        FileManagerHelper.deleteImage(filename: image.filename)
        modelContext.delete(image)
        windowManager.goBack()
    }
    
    private func copySourceURL() {
        guard let sourceURL = image.sourceURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sourceURL, forType: .string)
    }
}

#Preview {
    let image = DesignImage(filename: "test.png", originalName: "Test Image")
    return ImageDetailView(image: image)
        .environment(WindowManager())
        .modelContainer(for: [DesignFolder.self, DesignImage.self])
        .frame(width: 400, height: 450)
}
