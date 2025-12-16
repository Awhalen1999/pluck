//
//  PasteHint.swift
//  Pluck
//

import SwiftUI

// MARK: - Paste Badge (Interactive)

struct PasteBadge: View {
    var onPaste: (() -> Void)? = nil
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    private var isInteractive: Bool { onPaste != nil }
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "command")
                .font(.system(size: 8, weight: .medium))
            Text("V")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
        .overlay(
            Capsule()
                .stroke(Theme.border, lineWidth: 0.5)
        )
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            guard isInteractive else { return }
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isInteractive, !isPressed else { return }
                    isPressed = true
                }
                .onEnded { _ in
                    guard isInteractive else { return }
                    isPressed = false
                    onPaste?()
                }
        )
    }
    
    private var foregroundColor: Color {
        isHovered ? Theme.textPrimary : Theme.textSecondary
    }
    
    private var backgroundColor: Color {
        if isPressed { return Theme.cardBackgroundActive }
        if isHovered { return Theme.cardBackgroundHover }
        return Theme.cardBackground
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
                            .fill(Theme.cardBackground)
                    )
                }
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Theme.background)
                        .shadow(color: Theme.shadowMedium, radius: 8, y: 2)
                )
                .overlay(
                    Capsule()
                        .stroke(Theme.border, lineWidth: 0.5)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 10)
        .animation(.easeOut(duration: 0.2), value: isVisible)
    }
}
