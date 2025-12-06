//
//  CollapsedView.swift
//  Pluck
//

import SwiftUI

struct CollapsedView: View {
    @Environment(WindowManager.self) private var windowManager
    
    @State private var isDragging = false
    @State private var dragStart: Date?
    
    private let holdThreshold: TimeInterval = 0.15
    
    var body: some View {
        Image(systemName: "square.stack.3d.up.fill")
            .font(.system(size: 22))
            .foregroundStyle(.white.opacity(isDragging ? 1.0 : 0.9))
            .frame(width: 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(isDragging ? 0.1 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(isDragging ? 0.3 : 0), lineWidth: 1)
            )
            .shadow(color: .white.opacity(isDragging ? 0.2 : 0), radius: 8)
            .scaleEffect(isDragging ? 1.1 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = Date()
                        }
                        
                        guard let start = dragStart,
                              Date().timeIntervalSince(start) > holdThreshold else { return }
                        
                        if !isDragging { isDragging = true }
                        moveWindow(by: value.translation)
                    }
                    .onEnded { _ in
                        if !isDragging {
                            windowManager.showFolderList()
                        }
                        isDragging = false
                        dragStart = nil
                    }
            )
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
