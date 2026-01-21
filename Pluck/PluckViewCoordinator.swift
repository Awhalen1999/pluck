//
//  PluckViewCoordinator.swift
//  Pluck
//
//  Main panel UI that morphs between closed and open states.
//  Fills the window frame - sizing is controlled by FloatingPanelController.
//

import SwiftUI

// MARK: - Pluck View Coordinator

struct PluckViewCoordinator: View {
    
    @Environment(WindowManager.self) private var windowManager
    
    @State private var isHovering = false
    @State private var isDragging = false
    
    // MARK: - Computed Properties
    
    private var isInactive: Bool {
        !windowManager.isWindowActive
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { _ in
            panel(dockedEdge: windowManager.dockedEdge)
                .onHover { isHovering = $0 }
        }
    }
    
    // MARK: - Panel
    
    private func panel(dockedEdge: DockedEdge) -> some View {
        ZStack {
            background(dockedEdge: dockedEdge)
            content
                .inactiveStyle(isInactive)
            dragHandlePositioned
        }
        .clipShape(edgeShape(dockedEdge: dockedEdge))
        .overlay {
            edgeShape(dockedEdge: dockedEdge)
                .stroke(borderColor, lineWidth: 0.5)
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
    
    private var borderColor: Color {
        isHovering ? Theme.borderHover : Theme.border
    }
    
    // MARK: - Drag Handle
    
    private var dragHandlePositioned: some View {
        VStack {
            dragHandle
            Spacer()
        }
    }
    
    private var dragHandle: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().frame(width: 3, height: 3)
                }
            }
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().frame(width: 3, height: 3)
                }
            }
        }
        .foregroundStyle(handleColor)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .gesture(handleDragGesture)
        .animation(.easeOut(duration: 0.15), value: isDragging)
        .animation(.easeOut(duration: 0.15), value: isInactive)
    }
    
    private var handleColor: Color {
        if isDragging { return Theme.textSecondary }
        if isInactive { return Theme.textTertiary.opacity(0.5) }
        return Theme.textTertiary
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
        guard let window = findFloatingPanel(),
              let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        var frame = window.frame
        
        // Move in opposite direction (screen coords are inverted)
        frame.origin.y -= deltaY
        
        // Clamp to screen bounds
        let minY = screenRect.minY
        let maxY = screenRect.maxY - frame.height
        frame.origin.y = min(max(frame.origin.y, minY), maxY)
        
        window.setFrameOrigin(frame.origin)
    }
    
    private func savePosition() {
        guard let window = findFloatingPanel(),
              let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let yFromTop = screenRect.maxY - window.frame.origin.y - window.frame.height
        windowManager.updateYPosition(yFromTop)
        
        Log.debug("Saved panel position: yFromTop=\(yFromTop)", subsystem: .window)
    }
    
    private func findFloatingPanel() -> FloatingPanel? {
        NSApplication.shared.windows.first { $0 is FloatingPanel } as? FloatingPanel
    }
    
    // MARK: - Edge-Aware Shape
    
    private func edgeShape(dockedEdge: DockedEdge) -> UnevenRoundedRectangle {
        let r = PanelDimensions.cornerRadius
        
        switch dockedEdge {
        case .right:
            return UnevenRoundedRectangle(
                topLeadingRadius: r,
                bottomLeadingRadius: r,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
        case .left:
            return UnevenRoundedRectangle(
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
            edgeShape(dockedEdge: dockedEdge).fill(.ultraThinMaterial)
            edgeShape(dockedEdge: dockedEdge).fill(Theme.background)
        }
        .saturation(isInactive ? 0.85 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isInactive)
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
            .foregroundStyle(isInactive ? Theme.textTertiary : Theme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(isHovering && !windowManager.isOpen ? 1.1 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
            .animation(.easeOut(duration: 0.15), value: isInactive)
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
