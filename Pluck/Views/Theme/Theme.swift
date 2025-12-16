//
//  Theme.swift
//  Pluck
//
//  A dark, minimal liquid glass theme inspired by Apple's design language.
//

import SwiftUI

// MARK: - Theme

enum Theme {
    
    // MARK: - Background (Liquid Glass) — DARK GLASS (more minimal)
    static let background = Color.black.opacity(0.26)
    static let cardBackground = Color.black.opacity(0.28)
    static let cardBackgroundHover = Color.black.opacity(0.33)
    static let cardBackgroundActive = Color.black.opacity(0.40)
    
    // MARK: - Text (light on dark) — brighter
    static let textPrimary = Color.white.opacity(0.98)
    static let textSecondary = Color.white.opacity(0.82)
    static let textTertiary = Color.white.opacity(0.62)
    
    // MARK: - Borders (more blended/darker)
    // Lower opacities so the outline recedes into the glass.
    static let border = Color.white.opacity(0.08)
    static let borderHover = Color.white.opacity(0.11)
    static let borderActive = Color.white.opacity(0.14)
    
    // Inner contour — darker, faint.
    static let innerContour = Color.black.opacity(0.30)
    
    // MARK: - Shadows (tight + soft)
    static let shadowLight = Color.black.opacity(0.14)
    static let shadowMedium = Color.black.opacity(0.22)
    static let shadowHeavy = Color.black.opacity(0.34)
    
    // MARK: - Inactive State
    static let inactiveSaturation: Double = 0.85
    static let inactiveBrightness: Double = -0.02
    static let inactiveOpacity: Double = 0.85
    
    // MARK: - Accent / Status
    static let accent = Color.accentColor
    static let danger = Color.red
    static let success = Color.green
    
    // MARK: - Dimensions
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }
    
    // MARK: - Icon Button Styling
    static let iconButtonSize: CGFloat = 28
    static let iconSize: CGFloat = 12
}

// MARK: - View Modifiers

extension View {
    
    /// Standard frosted card style with minimal edge and inner contour (dark)
    func cardStyle(isHovered: Bool = false, isActive: Bool = false) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .fill(isActive ? Theme.cardBackgroundActive :
                          (isHovered ? Theme.cardBackgroundHover : Theme.cardBackground))
                    .overlay(GlassHighlight(cornerRadius: Theme.Radius.medium))
                    .shadow(color: Theme.shadowLight, radius: 1.5, y: 1)
            )
            // Ultra‑subtle outer border
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .stroke((isHovered ? Theme.borderHover : Theme.border), lineWidth: 0.75)
            )
            // Soft inner light to define the edge without a visible border
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium - 0.5)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                    .blendMode(.plusLighter)
                    .padding(0.5)
            )
            // Subtle inner contour for depth
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium - 1)
                    .stroke(Theme.innerContour, lineWidth: 0.5)
                    .blendMode(.multiply)
                    .padding(1)
            )
    }
    
    /// Icon button background (kept crisp)
    func iconButtonStyle(isHovered: Bool = false) -> some View {
        self
            .frame(width: Theme.iconButtonSize, height: Theme.iconButtonSize)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(isHovered ? Theme.cardBackgroundHover : Color.clear)
            )
    }
    
    /// Apply inactive/background window styling
    func inactiveStyle(_ isInactive: Bool) -> some View {
        self
            .saturation(isInactive ? Theme.inactiveSaturation : 1.0)
            .brightness(isInactive ? Theme.inactiveBrightness : 0)
            .opacity(isInactive ? Theme.inactiveOpacity : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isInactive)
    }
}

// MARK: - Reusable Components

struct IconButton: View {
    let icon: String
    let action: () -> Void
    var isDestructive: Bool = false
    var isInactive: Bool = false
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize, weight: .medium))
                .foregroundStyle(foregroundColor)
                .iconButtonStyle(isHovered: isHovered && !isInactive)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .opacity(isInactive ? Theme.inactiveOpacity : 1.0)
        .animation(.easeOut(duration: 0.15), value: isInactive)
    }
    
    private var foregroundColor: Color {
        if isInactive {
            return Theme.textTertiary
        }
        if isDestructive && isHovered {
            return Theme.danger
        }
        return isHovered ? Theme.textPrimary : Theme.textSecondary
    }
}

// MARK: - Glass Helpers

private struct GlassHighlight: View {
    let cornerRadius: CGFloat
    
    var body: some View {
        ZStack {
            // Top specular highlight (very soft)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.00)
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .blendMode(.plusLighter)
            
            // Gentle vertical tint (cool)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.screen)
        }
        .allowsHitTesting(false)
    }
}

struct GlassBackground: View {
    let cornerRadius: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Theme.background)
            .overlay(GlassHighlight(cornerRadius: cornerRadius))
            // Background container border even more blended and thinner
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.border.opacity(0.9), lineWidth: 0.4)
            )
            .shadow(color: Theme.shadowMedium, radius: 10, y: 0)
            .allowsHitTesting(false)
    }
}
