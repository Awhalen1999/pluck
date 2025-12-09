//
//  DropHint.swift
//  Pluck
//

import SwiftUI

// MARK: - Drop Badge

struct DropBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.system(size: 8, weight: .bold))
            Text("Drop")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.white.opacity(0.15))
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.8)
        
        HStack {
            Text("Folder Name")
                .foregroundStyle(.white)
            Spacer()
            DropBadge()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.1)))
        .padding(.horizontal)
    }
    .frame(width: 220, height: 100)
}
