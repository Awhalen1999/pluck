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
                    .fill(Theme.backgroundCard)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                            .tint(Theme.textTertiary)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(isHovered ? Theme.borderHover : Theme.border, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
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
                    .stroke(Theme.shadowMedium, lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    HStack {
        Rectangle()
            .fill(Theme.backgroundCard)
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .padding()
    .background(Theme.backgroundSolid)
}
