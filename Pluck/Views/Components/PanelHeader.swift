//
//  PanelHeader.swift
//  Pluck
//

import SwiftUI

struct PanelHeader: View {
    let title: String
    var showBackButton: Bool = false
    var accentColor: Color? = nil
    var onBack: (() -> Void)? = nil
    var onClose: () -> Void
    
    @Environment(WindowManager.self) private var windowManager
    
    var body: some View {
        HStack(spacing: 8) {
            if showBackButton {
                CircleButton.back(action: { onBack?() })
            }
            
            if !windowManager.isWindowActive {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .transition(.opacity.combined(with: .scale(scale: 0.5)))
            }
            
            if let accent = accentColor {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
            }
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            
            Spacer()
            
            CircleButton.close(action: onClose)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .animation(.easeOut(duration: 0.15), value: windowManager.isWindowActive)
    }
}
