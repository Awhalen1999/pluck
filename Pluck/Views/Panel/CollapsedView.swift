//
//  CollapsedView.swift
//  Pluck
//
//  ⚠️ DEPRECATED: This file is no longer used.
//  The collapsed icon functionality has been moved into FloatingPanelView as PanelIconView.
//  This file can be safely deleted.
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
            .foregroundStyle(iconColor)
            .frame(width: 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: PanelDimensions.collapsedCornerRadius)
                    .fill(isDragging ? Theme.backgroundCardHover : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PanelDimensions.collapsedCornerRadius)
                    .stroke(borderColor, lineWidth: 0.5)
            )
            .scaleEffect(scaleEffect)
            .wiggle(when: $isWiggling)
            .shadow(
                color: isDragging ? Theme.shadowMedium : Theme.shadowLight,
                radius: isDragging ? 16 : 4,
                y: isDragging ? 8 : 2
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDragging)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onDrop(of: ["public.image", "public.file-url"], isTargeted: $isDropTargeted) { _ in
                false
            }
            .onChange(of: isDropTargeted) { _, targeted in
                if targeted {
                    windowManager.showFolderList()
                }
            }
            .onDisappear {
                invalidateTimer()
            }
    }
    
    // MARK: - Computed Properties
    
    private var iconColor: Color {
        isDragging ? Theme.textPrimary : Theme.textPrimary
    }
    
    private var borderColor: Color {
        if isDragging { return Theme.borderHover }
        if isDropTargeted { return Theme.borderHover }
        return .clear
    }
    
    private var scaleEffect: CGFloat {
        if isDragging { return 1.08 }
        if isDropTargeted { return 1.05 }
        return 1.0
    }
    
    // MARK: - Timer
    
    private func invalidateTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
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
            // Use .common run loop mode for reliable timer firing
            holdTimer = Timer(timeInterval: holdDuration, repeats: false) { _ in
                DispatchQueue.main.async {
                    canDrag = true
                    isDragging = true
                    isWiggling = true
                }
            }
            RunLoop.current.add(holdTimer!, forMode: .common)
        }
        
        if canDrag {
            moveWindowVertically(by: value.translation.height)
        }
    }
    
    private func handleDragEnded() {
        invalidateTimer()
        
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

// MARK: - Preview

#Preview {
    CollapsedView()
        .environment(WindowManager())
}
