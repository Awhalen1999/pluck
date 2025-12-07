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
    @State private var wiggleAngle: Double = 0
    @State private var isDropTargeted = false
    
    private let holdDuration: TimeInterval = 0.8
    
    var body: some View {
        Image(systemName: "square.stack.3d.up.fill")
            .font(.system(size: 22))
            .foregroundStyle(.white.opacity(isDragging ? 1.0 : 0.9))
            .frame(width: 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(isDragging ? 0.08 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(isDragging ? 0.15 : (isDropTargeted ? 0.3 : 0)), lineWidth: 0.5)
            )
            .scaleEffect(isDragging ? 1.08 : (isDropTargeted ? 1.05 : 1.0))
            .rotationEffect(.degrees(wiggleAngle))
            .shadow(color: .black.opacity(isDragging ? 0.4 : 0.1), radius: isDragging ? 16 : 4, y: isDragging ? 8 : 2)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDragging)
            .animation(.easeOut(duration: 0.15), value: isDropTargeted)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if holdTimer == nil && !canDrag {
                            holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { _ in
                                DispatchQueue.main.async {
                                    canDrag = true
                                    isDragging = true
                                    startWiggle()
                                }
                            }
                        }
                        
                        if canDrag {
                            moveWindowVertically(by: value.translation.height)
                        }
                    }
                    .onEnded { _ in
                        holdTimer?.invalidate()
                        holdTimer = nil
                        
                        if !canDrag {
                            windowManager.showFolderList()
                        } else {
                            saveYPosition()
                        }
                        
                        stopWiggle()
                        isDragging = false
                        canDrag = false
                    }
            )
            .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { _ in
                // Don't actually handle drop here - just open folder list
                return false
            }
            .onChange(of: isDropTargeted) { _, targeted in
                if targeted {
                    // Auto-open folder list when file hovers over
                    windowManager.showFolderList()
                }
            }
    }
    
    // MARK: - Wiggle Animation
    
    private func startWiggle() {
        withAnimation(
            .easeInOut(duration: 0.1)
            .repeatForever(autoreverses: true)
        ) {
            wiggleAngle = 2.5
        }
    }
    
    private func stopWiggle() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            wiggleAngle = 0
        }
    }
    
    // MARK: - Window Movement
    
    private func moveWindowVertically(by deltaY: CGFloat) {
        guard let window = NSApplication.shared.windows.first(where: { $0 is FloatingPanel }),
              let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let edgeMargin: CGFloat = 10
        var frame = window.frame
        
        frame.origin.y -= deltaY
        frame.origin.y = max(screenRect.minY + edgeMargin, min(frame.origin.y, screenRect.maxY - frame.height - edgeMargin))
        
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

#Preview {
    CollapsedView()
        .environment(WindowManager())
}
