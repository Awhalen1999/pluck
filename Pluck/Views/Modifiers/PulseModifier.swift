//
//  PulseModifier.swift
//  Pluck
//

import SwiftUI

struct PulseModifier: ViewModifier {
    @Binding var trigger: Bool
    var scale: CGFloat = 1.03
    var duration: Double = 0.15
    
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? scale : 1.0)
            .animation(.spring(response: duration, dampingFraction: 0.6), value: isAnimating)
            .onChange(of: trigger) { _, newValue in
                guard newValue else { return }
                
                isAnimating = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    isAnimating = false
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + duration * 2) {
                    trigger = false
                }
            }
    }
}

extension View {
    func pulse(on trigger: Binding<Bool>, scale: CGFloat = 1.03) -> some View {
        modifier(PulseModifier(trigger: trigger, scale: scale))
    }
}
