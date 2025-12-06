//
//  CollapsedView.swift
//  Pluck
//

import SwiftUI

struct CollapsedView: View {
    @Environment(WindowManager.self) private var windowManager
    
    @State private var isDragging = false
    @State private var dragStartTime: Date?
    @State private var lastDragLocation: CGPoint?
    
    private let holdThreshold: TimeInterval = 0.15
    
    var body: some View {
        ZStack {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: 50, height: 50)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDragChanged(value)
                }
                .onEnded { _ in
                    handleDragEnded()
                }
        )
        .scaleEffect(isDragging ? 1.08 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        // First touch
        if dragStartTime == nil {
            dragStartTime = Date()
            lastDragLocation = value.location
            return
        }
        
        // Check if held long enough to drag
        guard let startTime = dragStartTime,
              Date().timeIntervalSince(startTime) > holdThreshold else {
            return
        }
        
        // Start dragging
        if !isDragging {
            isDragging = true
        }
        
        // Move window
        moveWindow(by: value.translation)
    }
    
    private func handleDragEnded() {
        if !isDragging {
            // It was a tap
            windowManager.showFolderList()
        }
        
        // Reset state
        isDragging = false
        dragStartTime = nil
        lastDragLocation = nil
    }
    
    private func moveWindow(by translation: CGSize) {
        guard let window = NSApplication.shared.windows.first(where: { $0 is FloatingPanel }) else { return }
        
        var frame = window.frame
        frame.origin.x += translation.width
        frame.origin.y -= translation.height
        window.setFrameOrigin(frame.origin)
    }
}

#Preview {
    CollapsedView()
        .environment(WindowManager())
}
