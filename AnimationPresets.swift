//
//  AnimationPresets.swift
//  Pluck
//
//  Centralized animation presets inspired by professional notch app patterns
//

import SwiftUI

// MARK: - Animation Presets

extension Animation {
    
    // MARK: - Panel State Transitions
    
    /// Smooth expansion when panel opens
    static let panelExpand = Animation.spring(
        response: 0.35,
        dampingFraction: 0.76,
        blendDuration: 0
    )
    
    /// Quick collapse when panel closes
    static let panelCollapse = Animation.spring(
        response: 0.3,
        dampingFraction: 0.8
    )
    
    /// Interactive spring for drag gestures
    static let panelDrag = Animation.interactiveSpring(
        response: 0.32,
        dampingFraction: 0.76
    )
    
    // MARK: - Card Interactions
    
    /// Subtle hover animation for cards
    static let cardHover = Animation.spring(
        response: 0.25,
        dampingFraction: 0.7
    )
    
    /// Quick press animation for buttons
    static let buttonPress = Animation.spring(
        response: 0.2,
        dampingFraction: 0.65
    )
    
    // MARK: - Content Transitions
    
    /// Smooth fade for appearing/disappearing elements
    static let elementFade = Animation.easeOut(duration: 0.15)
    
    /// Gentle scale for pop-in effects
    static let popIn = Animation.spring(
        response: 0.35,
        dampingFraction: 0.6
    )
    
    /// Continuous smooth animation for loading states
    static let continuous = Animation.easeInOut(duration: 0.5)
        .repeatForever(autoreverses: true)
}

// MARK: - Transition Presets

extension AnyTransition {
    
    /// Scale and fade in from center
    static var scaleAndFade: AnyTransition {
        .scale(scale: 0.9).combined(with: .opacity)
    }
    
    /// Asymmetric slide from right
    static var slideFromRight: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }
    
    /// Asymmetric slide from left
    static var slideFromLeft: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    /// Asymmetric scale with directional bias
    static var scaleFromTop: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
            removal: .opacity.combined(with: .move(edge: .top))
        )
    }
    
    /// Blur fade (requires custom modifier)
    static var blurFade: AnyTransition {
        .modifier(
            active: BlurFadeModifier(isActive: true),
            identity: BlurFadeModifier(isActive: false)
        )
    }
}

// MARK: - Blur Fade Modifier

struct BlurFadeModifier: ViewModifier {
    var isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .blur(radius: isActive ? 10 : 0)
            .opacity(isActive ? 0 : 1)
    }
}

// MARK: - Preview

#Preview {
    struct AnimationPreviewContainer: View {
        @State private var showElement = false
        @State private var hovering = false
        
        var body: some View {
            VStack(spacing: 30) {
                // Panel expansion preview
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.backgroundCard)
                    .frame(width: 200, height: showElement ? 300 : 50)
                    .animation(.panelExpand, value: showElement)
                
                // Card hover preview
                RoundedRectangle(cornerRadius: 10)
                    .fill(hovering ? Theme.backgroundCardHover : Theme.backgroundCard)
                    .frame(width: 180, height: 60)
                    .scaleEffect(hovering ? 1.02 : 1.0)
                    .animation(.cardHover, value: hovering)
                    .onHover { hovering = $0 }
                
                // Transition preview
                if showElement {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.purple)
                        .frame(width: 150, height: 100)
                        .transition(.scaleAndFade)
                }
                
                Button("Toggle") {
                    showElement.toggle()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
            }
            .padding()
            .frame(width: 400, height: 500)
            .background(Theme.backgroundSolid)
        }
    }
    
    return AnimationPreviewContainer()
}
