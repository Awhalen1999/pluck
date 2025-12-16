//
//  Theme.swift
//  Pluck
//
//  A clean, frosted glass theme inspired by native macOS design.
//

import SwiftUI

// MARK: - Theme

enum Theme {
    
    // MARK: - Background
    
    /// Main panel/window background - frosted white glass
    static let background = Color.white.opacity(0.78)
    
    /// Card/cell background - subtle lift from base
    static let cardBackground = Color.white.opacity(0.55)
    
    /// Hovered card state
    static let cardBackgroundHover = Color.white.opacity(0.75)
    
    /// Active/pressed card state
    static let cardBackgroundActive = Color.white.opacity(0.85)
    
    // MARK: - Text
    
    /// Primary text - high contrast on light
    static let textPrimary = Color.black.opacity(0.85)
    
    /// Secondary/supporting text
    static let textSecondary = Color.black.opacity(0.50)
    
    /// Tertiary/hint text
    static let textTertiary = Color.black.opacity(0.30)
    
    // MARK: - Borders
    
    /// Default border - barely visible structure
    static let border = Color.black.opacity(0.06)
    
    /// Hover/focus border
    static let borderHover = Color.black.opacity(0.12)
    
    /// Active/selected border
    static let borderActive = Color.black.opacity(0.18)
    
    // MARK: - Shadows
    
    /// Subtle shadow for cards
    static let shadowLight = Color.black.opacity(0.04)
    
    /// Medium shadow for elevated elements
    static let shadowMedium = Color.black.opacity(0.08)
    
    /// Heavy shadow for floating/dragged elements
    static let shadowHeavy = Color.black.opacity(0.15)
    
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
}

// MARK: - Reusable Components

/// Standard icon button used throughout the app
struct IconButton: View {
    let icon: String
    let action: () -> Void
    var isDestructive: Bool = false
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize, weight: .medium))
                .foregroundStyle(foregroundColor)
                .iconButtonStyle(isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    private var foregroundColor: Color {
        if isDestructive && isHovered {
            return Theme.danger
        }
        return isHovered ? Theme.textPrimary : Theme.textSecondary
    }
}
