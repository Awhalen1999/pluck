//
//  PopoutImageWindow.swift
//  Pluck
//

import AppKit
import SwiftUI

// MARK: - Popout Window Manager

@MainActor
final class PopoutWindowManager {
    static let shared = PopoutWindowManager()
    
    private var windows: [UUID: NSWindow] = [:]
    
    private init() {}
    
    func openImage(_ image: DesignImage) {
        // Load the full image
        guard let nsImage = FileManagerHelper.loadImage(filename: image.filename) else { return }
        
        let windowID = UUID()
        
        // Calculate window size (max 400px, maintain aspect ratio)
        let maxSize: CGFloat = 400
        let imageSize = nsImage.size
        let scale = min(maxSize / imageSize.width, maxSize / imageSize.height, 1.0)
        let windowSize = NSSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        
        // Position near center of screen
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let windowOrigin = NSPoint(
            x: screenFrame.midX - windowSize.width / 2 + CGFloat.random(in: -50...50),
            y: screenFrame.midY - windowSize.height / 2 + CGFloat.random(in: -50...50)
        )
        
        let contentRect = NSRect(origin: windowOrigin, size: windowSize)
        
        let window = PopoutImagePanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        
        let content = PopoutImageView(
            image: nsImage,
            title: image.originalName,
            onClose: { [weak self] in
                self?.closeWindow(id: windowID)
            }
        )
        
        window.contentView = NSHostingView(rootView: content)
        window.orderFront(nil)
        
        windows[windowID] = window
    }
    
    private func closeWindow(id: UUID) {
        windows[id]?.close()
        windows.removeValue(forKey: id)
    }
}

// MARK: - Popout Panel

final class PopoutImagePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Popout Image View

struct PopoutImageView: View {
    let image: NSImage
    let title: String
    let onClose: () -> Void
    
    @State private var isHovered = false
    @State private var isCloseHovered = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Image
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
            
            // Close button (visible on hover)
            if isHovered {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isCloseHovered ? .white : .white.opacity(0.8))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.black.opacity(isCloseHovered ? 0.8 : 0.6))
                        )
                }
                .buttonStyle(.plain)
                .onHover { isCloseHovered = $0 }
                .padding(8)
                .transition(.opacity)
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
