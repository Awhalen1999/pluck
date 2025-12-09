//
//  FloatingPanelView.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct FloatingPanelView: View {
    @Environment(WindowManager.self) private var windowManager
    
    var body: some View {
        ZStack {
            content
            
            // Inactive window overlay
            if !windowManager.isWindowActive {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.black.opacity(0.25))
                    .allowsHitTesting(false)
            }
        }
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .animation(.easeOut(duration: 0.15), value: windowManager.isWindowActive)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        switch windowManager.panelState {
        case .collapsed:
            CollapsedView()
                .frame(
                    width: PanelDimensions.collapsedSize.width,
                    height: PanelDimensions.collapsedSize.height
                )
                
        case .folderList:
            FolderListView()
                .frame(
                    width: PanelDimensions.folderListSize.width,
                    height: PanelDimensions.folderListSize.height
                )
                
        case .folderOpen(let folder):
            FolderDetailView(folder: folder)
                .frame(
                    width: PanelDimensions.folderDetailSize.width,
                    height: PanelDimensions.folderDetailSize.height
                )
                
        case .imageFocused(let image):
            ImageDetailView(image: image)
                .frame(
                    width: PanelDimensions.imageDetailSize.width,
                    height: PanelDimensions.imageDetailSize.height
                )
        }
    }
    
    // MARK: - Styling
    
    private var cornerRadius: CGFloat {
        switch windowManager.panelState {
        case .collapsed:
            return PanelDimensions.collapsedCornerRadius
        default:
            return PanelDimensions.expandedCornerRadius
        }
    }
    
    private var panelBackground: some View {
        ZStack {
            Color.black.opacity(0.85)
            
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
