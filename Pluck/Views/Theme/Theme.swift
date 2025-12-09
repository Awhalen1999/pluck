//
//  Theme.swift
//  Pluck
//

import SwiftUI

enum Theme {
    
    // MARK: - Backgrounds
    
    static let backgroundSolid = Color.black.opacity(0.75)
    static let backgroundCard = Color.white.opacity(0.06)
    static let backgroundCardHover = Color.white.opacity(0.10)
    static let backgroundCardActive = Color.white.opacity(0.14)
    
    // MARK: - Text
    
    static let textPrimary = Color.white.opacity(0.90)
    static let textSecondary = Color.white.opacity(0.50)
    static let textTertiary = Color.white.opacity(0.30)
    
    // MARK: - Borders
    
    static let border = Color.white.opacity(0.08)
    static let borderHover = Color.white.opacity(0.15)
    
    // MARK: - Shadows
    
    static let shadowLight = Color.black.opacity(0.15)
    static let shadowMedium = Color.black.opacity(0.30)
    static let shadowHeavy = Color.black.opacity(0.45)
}
