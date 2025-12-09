//
//  DropHint.swift
//  Pluck
//

import SwiftUI

struct DropBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.system(size: 8, weight: .bold))
            Text("Drop")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Theme.backgroundCardHover)
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Theme.backgroundSolid
        
        HStack {
            Text("Folder Name")
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            DropBadge()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.backgroundCard))
        .padding(.horizontal)
    }
    .frame(width: 220, height: 100)
}
