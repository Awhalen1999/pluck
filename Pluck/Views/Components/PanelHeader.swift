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
    
    var body: some View {
        HStack(spacing: 8) {
            if showBackButton, let onBack = onBack {
                CircleButton.back(action: onBack)
            }
            
            if let color = accentColor {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
            
            Spacer()
            
            CircleButton.close(action: onClose)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Simple header
        PanelHeader(
            title: "Folders",
            onClose: { }
        )
        
        // Header with back button
        PanelHeader(
            title: "My Project",
            showBackButton: true,
            onBack: { },
            onClose: { }
        )
        
        // Header with accent color
        PanelHeader(
            title: "Design Assets",
            showBackButton: true,
            accentColor: .purple,
            onBack: { },
            onClose: { }
        )
    }
    .background(Color.black.opacity(0.8))
}
