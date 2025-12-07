//
//  CollapsedView.swift
//  Pluck
//

import SwiftUI

struct CollapsedView: View {
    @Environment(WindowManager.self) private var windowManager
    
    @State private var isDragging = false
    @State private var holdTimer: Timer?
    @State private var canDrag = false
    @State private var isWiggling = false
    @State private var isDropTargeted = false
    
    private let holdDuration: TimeInterval = 0.8
    
    var body: some View {
        Image(systemName: "square.stack.3d.up.fill")
            .font(.system(size: 22))
            .foregroundStyle(.white.opacity(isDragging ? 1.0 : 0.9))
            .frame(width: 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: PanelDimensions.collapsedCornerRadius)
                    .fill(.white.opacity(isDragging ? 0.08 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PanelDimensions.collapsedCornerRadius)
                    .stroke(.white.opacity(borderOpacity), lineWidth: 0.5)
            )
            .scaleEffect(scaleEffect)
            .wiggle(when: $isWiggling)
            .shadow(
                color: .black.opacity(isDragging ? 0.4 : 0.1),
                radius: isDragging ? 16 : 4,
                y: isDragging ? 8 : 2
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDragging)
            .animation(.easeOut(duration: 0.15), value: isDropTargeted)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onDrop(of: ["public.image", "public.file-url"], isTargeted: $isDropTargeted) { _ in
                false // Don't handle drop, just detect hover
            }
            .onChange(of: isDropTargeted) { _, targeted in
                if targeted {
                    windowManager.showFolderList()
                }
            }
    }
    
    // MARK: - Computed Properties
    
    private var borderOpacity: Double {
        if isDragging { return 0.15 }
        if isDropTargeted { return 0.3 }
        return 0
    }
    
    private var scaleEffect: CGFloat {
        if isDragging { return 1.08 }
        if isDropTargeted { return 1.05 }
        return 1.0
    }
    
    // MARK: - Drag Gesture
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleDragChanged(value)
            }
            .onEnded { _ in
                handleDragEnded()
            }
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        if holdTimer == nil && !canDrag {
            holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { _ in
                DispatchQueue.main.async {
                    canDrag = true
                    isDragging = true
                    isWiggling = true
                }
            }
        }
        
        if canDrag {
            moveWindowVertically(by: value.translation.height)
        }
    }
    
    private func handleDragEnded() {
        holdTimer?.invalidate()
        holdTimer = nil
        
        if !canDrag {
            windowManager.showFolderList()
        } else {
            saveYPosition()
        }
        
        isWiggling = false
        isDragging = false
        canDrag = false
    }
    
    // MARK: - Window Movement
    
    private func moveWindowVertically(by deltaY: CGFloat) {
        guard let window = NSApplication.shared.windows.first(where: { $0 is FloatingPanel }),
              let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        var frame = window.frame
        
        frame.origin.y -= deltaY
        frame.origin.y = frame.origin.y.clamped(
            to: screenRect.minY + PanelDimensions.edgeMargin...screenRect.maxY - frame.height - PanelDimensions.edgeMargin
        )
        
        window.setFrameOrigin(frame.origin)
    }
    
    private func saveYPosition() {
        guard let window = NSApplication.shared.windows.first(where: { $0 is FloatingPanel }),
              let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let frame = window.frame
        let yFromTop = screenRect.maxY - frame.origin.y - frame.height
        windowManager.dockedYPosition = yFromTop
    }
}

// MARK: - Comparable Extension

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview {
    CollapsedView()
        .environment(WindowManager())
}
