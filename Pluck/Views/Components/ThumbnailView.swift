//
//  ThumbnailView.swift
//  Pluck
//

import SwiftUI

struct ThumbnailView: View {
    let image: DesignImage
    
    var size: CGFloat = 72
    var cornerRadius: CGFloat = 6
    
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
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
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

// MARK: - Mini Thumbnail (for stacks)

struct MiniThumbnailView: View {
    let nsImage: NSImage
    
    var size: CGFloat = 28
    var cornerRadius: CGFloat = 4
    
    var body: some View {
        Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.black.opacity(0.5), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    HStack {
        // Would need actual image data for preview
        Rectangle()
            .fill(.gray.opacity(0.3))
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .padding()
    .background(Color.black.opacity(0.8))
}
