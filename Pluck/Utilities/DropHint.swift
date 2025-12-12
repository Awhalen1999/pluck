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
        .foregroundStyle(.white.opacity(0.6))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.white.opacity(0.1))
        )
    }
}
