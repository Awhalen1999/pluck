//
//  Theme.swift
//  Pluck
//
//  A clean, liquid glass theme inspired by Apple's design language.
//

import SwiftUI

// MARK: - Theme

enum Theme {
    
    // MARK: - Background (Liquid Glass)
    
    /// Main panel/window background - very transparent for liquid glass effect
    static let background = Color.white.opacity(0.45)
    
    /// Card/cell background - subtle lift from base
    static let cardBackground = Color.white.opacity(0.35)
    
    /// Hovered card state
    static let cardBackgroundHover = Color.white.opacity(0.50)
    
    /// Active/pressed card state
    static let cardBackgroundActive = Color.white.opacity(0.60)
    
    // MARK: - Text
    
    /// Primary text - high contrast on light
    static let textPrimary = Color.black.opacity(0.85)
    
    /// Secondary/supporting text
    static let textSecondary = Color.black.opacity(0.50)
    
    /// Tertiary/hint text
    static let textTertiary = Color.black.opacity(0.30)
    
    // MARK: - Borders
    
    /// Default border - barely visible structure
    static let border = Color.white.opacity(0.60)
    
    /// Hover/focus border
    static let borderHover = Color.white.opacity(0.80)
    
    /// Active/selected border
    static let borderActive = Color.white.opacity(0.90)
    
    // MARK: - Shadows
    
    /// Subtle shadow for cards
    static let shadowLight = Color.black.opacity(0.06)
    
    /// Medium shadow for elevated elements
    static let shadowMedium = Color.black.opacity(0.10)
    
    /// Heavy shadow for floating/dragged elements
    static let shadowHeavy = Color.black.opacity(0.18)
    
    // MARK: - Inactive State
    
    /// Saturation multiplier when window is inactive
    static let inactiveSaturation: Double = 0.6
    
    /// Brightness adjustment when window is inactive
    static let inactiveBrightness: Double = 0.03
    
    /// Opacity for interactive elements when inactive
    static let inactiveOpacity: Double = 0.7
    
    // MARK: - Accent
    
    /// System accent for interactive elements
    static let accent = Color.accentColor
    
    /// Danger/destructive actions
    static let danger = Color.red
    
    /// Success/confirmation
    static let success = Color.green
    
    // MARK: - Dimensions
    
    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
    }
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }
    
    // MARK: - Icon Button Styling
    
    /// Standard icon button size
    static let iconButtonSize: CGFloat = 28
    
    /// Icon font size
    static let iconSize: CGFloat = 12
}

// MARK: - View Modifiers

extension View {
    
    /// Standard frosted card style
    func cardStyle(isHovered: Bool = false, isActive: Bool = false) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .fill(isActive ? Theme.cardBackgroundActive : (isHovered ? Theme.cardBackgroundHover : Theme.cardBackground))
                    .shadow(color: Theme.shadowLight, radius: 2, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .stroke(isHovered ? Theme.borderHover : Theme.border, lineWidth: 1)
            )
    }
    
    /// Icon button background
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
            .animation(.easeInOut(duration: 0.15), value: isInactive)
    }
}

// MARK: - Reusable Components

/// Standard icon button used throughout the app
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
