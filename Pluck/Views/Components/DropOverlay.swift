//
//  DropOverlay.swift
//  Pluck
//

import SwiftUI

struct DropOverlay: View {
    let isTargeted: Bool
    var cornerRadius: CGFloat = 12
    var accentColor: Color? = nil
    
    var body: some View {
        Group {
            if isTargeted {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(strokeColor, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.white.opacity(0.05))
                    )
                    .padding(4)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }
    
    private var strokeColor: Color {
        accentColor?.opacity(0.6) ?? .white.opacity(0.3)
    }
}

// MARK: - View Modifier

struct DropTargetModifier: ViewModifier {
    @Binding var isTargeted: Bool
    var cornerRadius: CGFloat = 12
    var accentColor: Color? = nil
    let supportedTypes: [String]
    let onDrop: ([NSItemProvider]) -> Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                DropOverlay(
                    isTargeted: isTargeted,
                    cornerRadius: cornerRadius,
                    accentColor: accentColor
                )
            )
            .onDrop(of: supportedTypes, isTargeted: $isTargeted) { providers in
                onDrop(providers)
            }
    }
}

extension View {
    func dropTarget(
        isTargeted: Binding<Bool>,
        cornerRadius: CGFloat = 12,
        accentColor: Color? = nil,
        supportedTypes: [String] = ["public.image", "public.file-url"],
        onDrop: @escaping ([NSItemProvider]) -> Bool
    ) -> some View {
        modifier(
            DropTargetModifier(
                isTargeted: isTargeted,
                cornerRadius: cornerRadius,
                accentColor: accentColor,
                supportedTypes: supportedTypes,
                onDrop: onDrop
            )
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        RoundedRectangle(cornerRadius: 12)
            .fill(.white.opacity(0.1))
            .frame(width: 200, height: 100)
            .overlay(DropOverlay(isTargeted: false))
        
        RoundedRectangle(cornerRadius: 12)
            .fill(.white.opacity(0.1))
            .frame(width: 200, height: 100)
            .overlay(DropOverlay(isTargeted: true))
        
        RoundedRectangle(cornerRadius: 12)
            .fill(.white.opacity(0.1))
            .frame(width: 200, height: 100)
            .overlay(DropOverlay(isTargeted: true, accentColor: .purple))
    }
    .padding()
    .background(Color.black.opacity(0.8))
}
