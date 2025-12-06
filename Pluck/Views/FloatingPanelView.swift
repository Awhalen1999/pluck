//
//  FloatingPanelView.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct FloatingPanelView: View {
    @Environment(WindowManager.self) private var windowManager
    
    // MARK: - Panel Dimensions
    
    private enum Dimensions {
        static let collapsedSize: CGFloat = 50
        static let standardWidth: CGFloat = 280
        static let standardHeight: CGFloat = 350
        static let expandedWidth: CGFloat = 400
        static let expandedHeight: CGFloat = 450
        static let collapsedRadius: CGFloat = 12
        static let expandedRadius: CGFloat = 16
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            switch windowManager.panelState {
            case .collapsed:
                CollapsedView()
                    .frame(width: Dimensions.collapsedSize, height: Dimensions.collapsedSize)
                    
            case .folderList:
                FolderListView()
                    .frame(width: Dimensions.standardWidth, height: Dimensions.standardHeight)
                    
            case .folderOpen(let folder):
                FolderDetailView(folder: folder)
                    .frame(width: Dimensions.standardWidth, height: Dimensions.standardHeight)
                    
            case .imageFocused(let image):
                ImageDetailView(image: image)
                    .frame(width: Dimensions.expandedWidth, height: Dimensions.expandedHeight)
            }
        }
        .background(panelBackground)
        .overlay(panelBorder)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    // MARK: - Styling
    
    private var cornerRadius: CGFloat {
        windowManager.panelState == .collapsed ? Dimensions.collapsedRadius : Dimensions.expandedRadius
    }
    
    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.black.opacity(0.75))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(0.5)
            )
    }
    
    private var panelBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
    }
}

// MARK: - Preview

#Preview {
    FloatingPanelView()
        .environment(WindowManager())
        .modelContainer(for: [DesignFolder.self, DesignImage.self])
}
