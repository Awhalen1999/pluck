//
//  DropHint.swift
//  Pluck
//

import SwiftUI

struct DropBadge: View {
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.system(size: 8, weight: .bold))
            Text("Drop")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(isHovered ? Theme.textPrimary : Theme.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isHovered ? Theme.cardBackgroundHover : Theme.cardBackground)
        )
        .overlay(
            Capsule()
                .stroke(Theme.border, lineWidth: 0.5)
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
