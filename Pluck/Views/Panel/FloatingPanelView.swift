//
//  FloatingPanelView.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct FloatingPanelView: View {
    @Environment(WindowManager.self) private var windowManager
    
    var body: some View {
        content
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.border, lineWidth: 1)
            )
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
                    height: currentListHeight
                )
                
        case .folderOpen(let folder):
            FolderDetailView(folder: folder)
                .frame(
                    width: PanelDimensions.folderDetailSize.width,
                    height: currentListHeight
                )
                
        case .imageFocused(let image):
            ImageDetailView(image: image)
                .frame(
                    width: PanelDimensions.imageDetailSize.width,
                    height: PanelDimensions.imageDetailSize.height
                )
        }
    }
    
    // MARK: - Dynamic Height
    
    private var currentListHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        return PanelDimensions.listHeight(screenHeight: screenHeight)
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
            Theme.backgroundSolid
            
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
