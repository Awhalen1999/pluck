//
//  FloatingPanelView.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct FloatingPanelView: View {
    @Environment(WindowManager.self) private var windowManager
    
    // MARK: - Dimensions
    
    private enum Dimensions {
        static let collapsedSize: CGFloat = 50
        static let listWidth: CGFloat = 220
        static let listHeight: CGFloat = 350
        static let detailWidth: CGFloat = 240
        static let detailHeight: CGFloat = 340
        static let focusedWidth: CGFloat = 360
        static let focusedHeight: CGFloat = 420
    }
    
    // MARK: - Body
    
    var body: some View {
        content
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        switch windowManager.panelState {
        case .collapsed:
            CollapsedView()
                .frame(width: Dimensions.collapsedSize, height: Dimensions.collapsedSize)
                
        case .folderList:
            FolderListView()
                .frame(width: Dimensions.listWidth, height: Dimensions.listHeight)
                
        case .folderOpen(let folder):
            FolderDetailView(folder: folder)
                .frame(width: Dimensions.detailWidth, height: Dimensions.detailHeight)
                
        case .imageFocused(let image):
            ImageDetailView(image: image)
                .frame(width: Dimensions.focusedWidth, height: Dimensions.focusedHeight)
        }
    }
    
    // MARK: - Styling
    
    private var cornerRadius: CGFloat {
        windowManager.panelState == .collapsed ? 12 : 14
    }
    
    private var panelBackground: some View {
        ZStack {
            // Base dark fill
            Color.black.opacity(0.85)
            
            // Subtle glass effect
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .opacity(0.3)
        }
    }
}

// MARK: - Preview

#Preview {
    FloatingPanelView()
        .environment(WindowManager())
        .modelContainer(for: [DesignFolder.self, DesignImage.self])
}
