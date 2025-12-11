//
//  ImageDetailView.swift
//  Pluck
//

import SwiftUI

struct ImageDetailView: View {
    let image: DesignImage
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Spacer()
            
            Text("Image: \(image.originalName)")
                .foregroundStyle(.white.opacity(0.5))
            
            Spacer()
        }
    }
    
    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
    }
}
