//
//  CircleButton.swift
//  Pluck
//

import SwiftUI

struct CircleButton: View {
    let icon: String
    let action: () -> Void
    
    var size: CGFloat = 24
    var iconSize: CGFloat = 10
    var iconWeight: Font.Weight = .semibold
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: iconWeight))
                .foregroundStyle(isHovered ? Theme.textSecondary : Theme.textTertiary)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isHovered ? Theme.backgroundCardHover : Theme.backgroundCard)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Convenience Initializers

extension CircleButton {
    static func close(action: @escaping () -> Void) -> CircleButton {
        CircleButton(icon: "xmark", action: action)
    }
    
    static func back(action: @escaping () -> Void) -> CircleButton {
        CircleButton(icon: "chevron.left", action: action)
    }
    
    static func delete(action: @escaping () -> Void) -> CircleButton {
        CircleButton(icon: "trash", action: action)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        CircleButton.back { }
        CircleButton.close { }
        CircleButton.delete { }
        CircleButton(icon: "plus", action: { })
    }
    .padding()
    .background(Theme.backgroundSolid)
}
