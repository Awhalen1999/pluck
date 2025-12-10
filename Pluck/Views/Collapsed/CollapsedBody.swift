//
//  CollapsedBody.swift
//  Pluck
//
//  Created by Alex Whalen on 2025-12-10.
//

import SwiftUI

/// Implementation of the collapsed icon with drag/drop functionality
struct CollapsedBody: View {
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
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: PanelDimensions.collapsedCornerRadius)
                    .fill(isDragging ? Theme.backgroundCardHover : .clear)
            )
            .scaleEffect(scaleEffect)
            .wiggle(when: $isWiggling)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDragging)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onDrop(of: ["public.image", "public.file-url"], isTargeted: $isDropTargeted) { _ in
                false
            }
            .onChange(of: isDropTargeted) { _, targeted in
                if targeted && isCollapsed {
                    windowManager.showFolderList()
                }
            }
            .onDisappear {
                invalidateTimer()
            }
    }
    
    // MARK: - Computed Properties
    
    private var isCollapsed: Bool {
        if case .collapsed = windowManager.panelState {
            return true
        }
        return false
    }
    
    private var scaleEffect: CGFloat {
        if isDragging { return 1.08 }
        if isDropTargeted { return 1.05 }
        return 1.0
    }
    
    // MARK: - Timer Management
    
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
            // Quick tap - toggle expansion
            if isCollapsed {
                windowManager.showFolderList()
            }
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
