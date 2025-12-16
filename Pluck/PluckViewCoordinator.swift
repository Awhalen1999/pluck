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
    @State private var isDragging = false
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            panel(dockedEdge: windowManager.dockedEdge)
                .onHover { isHovering = $0 }
        }
    }
    
    // MARK: - Panel
    
    private func panel(dockedEdge: DockedEdge) -> some View {
        ZStack {
            background(dockedEdge: dockedEdge)
            content
            dragHandlePositioned
        }
        .clipShape(edgeShape(dockedEdge: dockedEdge))
        .overlay {
            edgeShape(dockedEdge: dockedEdge)
                .stroke(Theme.border, lineWidth: 1)
        }
        .shadow(color: Theme.shadowMedium, radius: 12, x: dockedEdge == .right ? -4 : 4, y: 0)
    }
    
    // MARK: - Drag Handle Positioning
    
    private var dragHandlePositioned: some View {
        VStack {
            dragHandle
            Spacer()
        }
    }
    
    // MARK: - Drag Handle (Grip Dots)
    
    private var dragHandle: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Circle().frame(width: 3, height: 3)
                Circle().frame(width: 3, height: 3)
                Circle().frame(width: 3, height: 3)
            }
            HStack(spacing: 3) {
                Circle().frame(width: 3, height: 3)
                Circle().frame(width: 3, height: 3)
                Circle().frame(width: 3, height: 3)
            }
        }
        .foregroundStyle(isDragging ? Theme.textSecondary : Theme.textTertiary)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .gesture(handleDragGesture)
        .animation(.easeOut(duration: 0.15), value: isDragging)
    }
    
    private var handleDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                movePanel(by: value.translation.height)
            }
            .onEnded { _ in
                isDragging = false
                savePosition()
            }
    }
    
    // MARK: - Panel Movement
    
    private func movePanel(by deltaY: CGFloat) {
        guard let window = NSApplication.shared.windows.first(where: { $0 is FloatingPanel }),
              let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        var frame = window.frame
        
        frame.origin.y -= deltaY
        frame.origin.y = frame.origin.y.clamped(
            to: screenRect.minY...screenRect.maxY - frame.height
        )
        
        window.setFrameOrigin(frame.origin)
    }
    
    private func savePosition() {
        guard let window = NSApplication.shared.windows.first(where: { $0 is FloatingPanel }),
              let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let yFromTop = screenRect.maxY - window.frame.origin.y - window.frame.height
        windowManager.updateYPosition(yFromTop)
    }
    
    // MARK: - Edge-Aware Shape
    
    private func edgeShape(dockedEdge: DockedEdge) -> UnevenRoundedRectangle {
        let r = PanelDimensions.cornerRadius
        
        return switch dockedEdge {
        case .right:
            UnevenRoundedRectangle(
                topLeadingRadius: r,
                bottomLeadingRadius: r,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
        case .left:
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
            // Base frosted material
            edgeShape(dockedEdge: dockedEdge)
                .fill(.ultraThinMaterial)
            
            // Subtle white overlay for the frosted look
            edgeShape(dockedEdge: dockedEdge)
                .fill(Theme.background)
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
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(isHovering && !windowManager.isOpen ? 1.1 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
            .contentShape(Rectangle())
            .onTapGesture {
                windowManager.toggle()
            }
    }
    
    // MARK: - Open Content
    
    private var openContent: some View {
        ContentView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
