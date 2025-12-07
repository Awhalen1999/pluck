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
    var iconOpacity: Double = 0.4
    var backgroundOpacity: Double = 0.1
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: iconWeight))
                .foregroundStyle(.white.opacity(isHovered ? iconOpacity + 0.2 : iconOpacity))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(.white.opacity(isHovered ? backgroundOpacity + 0.05 : backgroundOpacity))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
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
        CircleButton(
            icon: "trash",
            action: action,
            iconOpacity: 0.6
        )
    }
}

#Preview {
    HStack(spacing: 16) {
        CircleButton.back { }
        CircleButton.close { }
        CircleButton.delete { }
        CircleButton(icon: "plus", action: { })
    }
    .padding()
    .background(Color.black.opacity(0.8))
}
