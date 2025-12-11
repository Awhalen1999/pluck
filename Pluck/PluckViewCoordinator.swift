//
//  PluckViewCoordinator.swift
//  Pluck
//
//  Created by Alex Whalen on 2025-12-10.
//

import SwiftUI
import SwiftData

/// Main coordinator that manages panel state and displays the appropriate view
/// Simple switch statement - one state = one view
struct PluckViewCoordinator: View {
    @Environment(WindowManager.self) private var windowManager
    
    var body: some View {
        currentView
            .frame(width: currentWidth, height: currentHeight)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
    
    // MARK: - View Router (Clean & Simple)
    
    @ViewBuilder
    private var currentView: some View {
        switch windowManager.panelState {
        case .collapsed:
            CollapsedView()
            
        case .folderList:
            FolderListView()
            
        case .folderOpen(let folder):
            FolderDetailView(folder: folder)
            
        case .imageFocused(let image):
            ImageDetailView(image: image)
        }
    }
    
    // MARK: - Dynamic Dimensions
    
    private var currentWidth: CGFloat {
        guard let screen = NSScreen.main else { return PanelDimensions.collapsedSize.width }
        let size = PanelDimensions.size(
            for: windowManager.panelState,
            screenHeight: screen.visibleFrame.height
        )
        return size.width
    }
    
    private var currentHeight: CGFloat {
        guard let screen = NSScreen.main else { return PanelDimensions.collapsedSize.height }
        let size = PanelDimensions.size(
            for: windowManager.panelState,
            screenHeight: screen.visibleFrame.height
        )
        return size.height
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
    PluckViewCoordinator()
        .environment(WindowManager())
        .environment(ClipboardWatcher())
        .environment(PasteController(windowManager: WindowManager(), clipboardWatcher: ClipboardWatcher()))
        .modelContainer(for: [DesignFolder.self, DesignImage.self])
}
