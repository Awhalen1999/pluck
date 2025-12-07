//
//  PasteHint.swift
//  Pluck
//

import SwiftUI

// MARK: - Paste Badge (for folder cards)

struct PasteBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "command")
                .font(.system(size: 8, weight: .medium))
            Text("V")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(.white.opacity(0.15))
        )
    }
}

// MARK: - Paste Overlay (bottom hint)

struct PasteOverlay: View {
    let isVisible: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            if isVisible {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11))
                    
                    Text("Paste with")
                        .font(.system(size: 11))
                    
                    HStack(spacing: 2) {
                        Image(systemName: "command")
                            .font(.system(size: 9, weight: .medium))
                        Text("V")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.1))
                    )
                }
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.4))
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.08), lineWidth: 0.5)
                        )
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 10)
        .animation(.easeOut(duration: 0.2), value: isVisible)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.8)
        
        VStack(spacing: 30) {
            // Badge preview
            HStack {
                Text("Folder Name")
                    .foregroundStyle(.white)
                Spacer()
                PasteBadge()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.1)))
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 40)
        
        // Overlay preview
        PasteOverlay(isVisible: true)
    }
    .frame(width: 220, height: 350)
}
