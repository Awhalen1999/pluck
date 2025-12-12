//
//  WiggleModifier.swift
//  Pluck
//

import SwiftUI

struct WiggleModifier: ViewModifier {
    @Binding var isWiggling: Bool
    var angle: Double = 2.5
    
    @State private var wiggleAngle: Double = 0
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(wiggleAngle))
            .onChange(of: isWiggling) { _, wiggling in
                if wiggling {
                    startWiggle()
                } else {
                    stopWiggle()
                }
            }
    }
    
    private func startWiggle() {
        withAnimation(
            .easeInOut(duration: 0.1)
            .repeatForever(autoreverses: true)
        ) {
            wiggleAngle = angle
        }
    }
    
    private func stopWiggle() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            wiggleAngle = 0
        }
    }
}

extension View {
    func wiggle(when isWiggling: Binding<Bool>, angle: Double = 2.5) -> some View {
        modifier(WiggleModifier(isWiggling: isWiggling, angle: angle))
    }
}
