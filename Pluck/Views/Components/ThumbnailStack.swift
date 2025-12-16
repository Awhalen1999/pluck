//
//  ThumbnailStack.swift
//  Pluck
//

import SwiftUI

struct ThumbnailStack: View {
    let thumbnails: [NSImage]
    let totalCount: Int
    
    var maxVisible: Int = 4
    var thumbnailSize: CGFloat = 28
    var overlap: CGFloat = 8
    
    var body: some View {
        HStack(spacing: -overlap) {
            ForEach(Array(thumbnails.prefix(maxVisible).enumerated()), id: \.offset) { index, image in
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: Theme.shadowLight, radius: 1, y: 1)
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
