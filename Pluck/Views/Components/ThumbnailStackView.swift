//
//  ThumbnailStackView.swift
//  Pluck
//

import SwiftUI

struct ThumbnailStackView: View {
    let thumbnails: [NSImage]
    let totalCount: Int
    
    var maxVisible: Int = 4
    var thumbnailSize: CGFloat = 28
    var overlap: CGFloat = 8
    
    var body: some View {
        HStack(spacing: -overlap) {
            ForEach(Array(thumbnails.prefix(maxVisible).enumerated()), id: \.offset) { index, image in
                MiniThumbnailView(nsImage: image, size: thumbnailSize)
                    .zIndex(Double(maxVisible - index))
            }
            
            if totalCount > maxVisible {
                Text("+\(totalCount - maxVisible)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.leading, overlap + 4)
            }
            
            Spacer()
        }
    }
}

// MARK: - Empty State

struct ThumbnailStackEmptyView: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
            
            Text("Drop images here")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        ThumbnailStackEmptyView()
        
        Text("(Stack preview requires images)")
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
    }
    .padding()
    .background(Theme.backgroundSolid)
}
