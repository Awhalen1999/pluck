//
//  PluckViewCoordinator.swift
//  Pluck
//
//  Created by Alex Whalen on 2025-12-10.
//

import SwiftUI
import SwiftData

/// Main coordinator that manages panel state and displays the appropriate view
struct PluckViewCoordinator: View {
    @Environment(WindowManager.self) private var windowManager
    
    var body: some View {
        VStack(spacing: 0) {
            // The icon/header is always present
            CollapsedView()
                .frame(
                    width: PanelDimensions.collapsedSize.width,
                    height: PanelDimensions.collapsedSize.height
                )
            
            // Content expands below when not collapsed
            if !isCollapsed {
                expandedContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(
            width: currentWidth,
            height: currentHeight
        )
        .background(panelBackground)
        .clipShape(DockedPanelShape(dockedEdge: windowManager.dockedEdge, cornerRadius: cornerRadius))
        .overlay(
            DockedPanelShape(dockedEdge: windowManager.dockedEdge, cornerRadius: cornerRadius)
                .stroke(Theme.border, lineWidth: 1)
        )
        .animation(animationForCurrentTransition, value: windowManager.panelState)
    }
    
    // MARK: - State Helpers
    
    private var isCollapsed: Bool {
        if case .collapsed = windowManager.panelState {
            return true
        }
        return false
    }
    
    /// Choose appropriate animation based on state transition
    private var animationForCurrentTransition: Animation {
        // Use faster collapse animation when closing
        isCollapsed ? .panelCollapse : .panelExpand
    }
    
    // MARK: - Expanded Content Router
    
    @ViewBuilder
    private var expandedContent: some View {
        Group {
            switch windowManager.panelState {
            case .collapsed:
                EmptyView()
                
            case .folderList:
                FolderListView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
                    
            case .folderOpen(let folder):
                FolderDetailView(folder: folder)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                    
            case .imageFocused(let image):
                ImageDetailView(image: image)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        // Add subtle blur during state transitions
        .opacity(isCollapsed ? 0 : 1)
        .blur(radius: isCollapsed ? 8 : 0)
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
        isCollapsed ? PanelDimensions.collapsedCornerRadius : PanelDimensions.expandedCornerRadius
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
