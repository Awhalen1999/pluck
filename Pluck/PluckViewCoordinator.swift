//
//  PluckViewCoordinator.swift
//  Pluck
//
//  Main panel UI that morphs between closed and open states.
//  Fills the window frame - sizing is controlled by FloatingPanelController.
//

import SwiftUI

struct PluckViewCoordinator: View {
    
    @Environment(WindowManager.self) private var windowManager
    @State private var isHovering = false
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            panel(dockedEdge: windowManager.dockedEdge)
                .onTapGesture { windowManager.toggle() }
                .onHover { isHovering = $0 }
        }
    }
    
    // MARK: - Panel
    
    private func panel(dockedEdge: DockedEdge) -> some View {
        ZStack {
            background(dockedEdge: dockedEdge)
            content
        }
        .clipShape(edgeShape(dockedEdge: dockedEdge))
        .overlay {
            edgeShape(dockedEdge: dockedEdge)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
    
    // MARK: - Edge-Aware Shape
    
    /// Rounds only the corners facing away from the screen edge
    private func edgeShape(dockedEdge: DockedEdge) -> UnevenRoundedRectangle {
        let r = PanelDimensions.cornerRadius
        
        return switch dockedEdge {
        case .right:
            // Docked right: round left corners only
            UnevenRoundedRectangle(
                topLeadingRadius: r,
                bottomLeadingRadius: r,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
        case .left:
            // Docked left: round right corners only
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: r,
                topTrailingRadius: r
            )
        }
    }
    
    // MARK: - Background
    
    private func background(dockedEdge: DockedEdge) -> some View {
        ZStack {
            Color.black.opacity(0.9)
            
            edgeShape(dockedEdge: dockedEdge)
                .fill(.ultraThinMaterial)
                .opacity(0.2)
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        let isOpen = windowManager.isOpen
        
        ZStack {
            closedContent
                .opacity(isOpen ? 0 : 1)
                .scaleEffect(isOpen ? 0.8 : 1)
            
            openContent
                .opacity(isOpen ? 1 : 0)
                .scaleEffect(isOpen ? 1 : 0.95)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isOpen)
    }
    
    // MARK: - Closed Content
    
    private var closedContent: some View {
        Image(systemName: "square.stack.3d.up.fill")
            .font(.system(size: 22))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(isHovering && !windowManager.isOpen ? 1.1 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
    }
    
    // MARK: - Open Content
    
    private var openContent: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            placeholder
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var header: some View {
        HStack {
            Spacer()
            
            Button(action: { windowManager.close() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
    
    private var placeholder: some View {
        Text("Content goes here")
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.4))
    }
}

// MARK: - Preview

#Preview("Closed") {
    PluckViewCoordinator()
        .environment(WindowManager())
        .frame(width: 50, height: 100)
}

#Preview("Open") {
    let manager = WindowManager()
    manager.open()
    
    return PluckViewCoordinator()
        .environment(manager)
        .frame(width: 220, height: 400)
}
