//
//  DropOverlay.swift
//  Pluck
//

import SwiftUI

struct DropOverlay: View {
    let isTargeted: Bool
    var cornerRadius: CGFloat = 12
    
    var body: some View {
        Group {
            if isTargeted {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.borderHover, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Theme.backgroundCard)
                    )
            }
        }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }
}

// MARK: - View Modifier

struct DropTargetModifier: ViewModifier {
    @Binding var isTargeted: Bool
    var cornerRadius: CGFloat = 12
    let supportedTypes: [String]
    let onDrop: ([NSItemProvider]) -> Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                DropOverlay(
                    isTargeted: isTargeted,
                    cornerRadius: cornerRadius
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
        supportedTypes: [String] = ["public.image", "public.file-url"],
        onDrop: @escaping ([NSItemProvider]) -> Bool
    ) -> some View {
        modifier(
            DropTargetModifier(
                isTargeted: isTargeted,
                cornerRadius: cornerRadius,
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
            .fill(Theme.backgroundCard)
            .frame(width: 200, height: 100)
            .overlay(DropOverlay(isTargeted: false, cornerRadius: 12))
        
        RoundedRectangle(cornerRadius: 12)
            .fill(Theme.backgroundCard)
            .frame(width: 200, height: 100)
            .overlay(DropOverlay(isTargeted: true, cornerRadius: 12))
    }
    .padding()
    .background(Theme.backgroundSolid)
}
