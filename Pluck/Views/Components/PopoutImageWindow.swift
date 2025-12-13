//
//  PopoutImageWindow.swift
//  Pluck
//

import AppKit
import SwiftUI

// MARK: - Window Mode

enum PopoutWindowMode: String, CaseIterable {
    case drag     // Window can be dragged around
    case resize   // Window can be resized from corners
    case locked   // Window is locked in place
    
    var icon: String {
        switch self {
        case .drag: return "hand.draw"
        case .resize: return "arrow.up.left.and.arrow.down.right"
        case .locked: return "lock"
        }
    }
    
    var activeIcon: String {
        switch self {
        case .drag: return "hand.draw.fill"
        case .resize: return "arrow.up.left.and.arrow.down.right"
        case .locked: return "lock.fill"
        }
    }
}

// MARK: - Popout Window Manager

@MainActor
final class PopoutWindowManager {
    static let shared = PopoutWindowManager()
    
    private var windows: [UUID: PopoutImagePanel] = [:]
    
    private init() {}
    
    func openImage(_ image: DesignImage) {
        guard let nsImage = FileManagerHelper.loadImage(filename: image.filename) else { return }
        
        let windowID = UUID()
        
        // Calculate initial size (max 400px, maintain aspect ratio)
        let maxSize: CGFloat = 400
        let imageSize = nsImage.size
        let scale = min(maxSize / imageSize.width, maxSize / imageSize.height, 1.0)
        let windowSize = NSSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        
        // Position near center of screen with slight randomness
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
        window.hasShadow = false // removed shadow
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.imageAspectRatio = imageSize.width / imageSize.height
        window.originalImageSize = imageSize
        
        let content = PopoutImageView(
            image: nsImage,
            title: image.originalName,
            onClose: { [weak self] in
                self?.closeWindow(id: windowID)
            },
            onModeChanged: { [weak self] mode in
                self?.setWindowMode(id: windowID, mode: mode)
            },
            onResizeTopLeft: { [weak self] delta in
                self?.resizeFromCorner(id: windowID, corner: .topLeft, delta: delta)
            },
            onResizeTopRight: { [weak self] delta in
                self?.resizeFromCorner(id: windowID, corner: .topRight, delta: delta)
            },
            onResizeBottomLeft: { [weak self] delta in
                self?.resizeFromCorner(id: windowID, corner: .bottomLeft, delta: delta)
            },
            onResizeBottomRight: { [weak self] delta in
                self?.resizeFromCorner(id: windowID, corner: .bottomRight, delta: delta)
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
    
    private func setWindowMode(id: UUID, mode: PopoutWindowMode) {
        guard let window = windows[id] else { return }
        
        switch mode {
        case .drag:
            window.isMovableByWindowBackground = true
        case .resize:
            window.isMovableByWindowBackground = false
        case .locked:
            window.isMovableByWindowBackground = false
        }
    }
    
    // MARK: - Resize Methods
    
    private func resizeFromCorner(id: UUID, corner: ResizeCorner, delta: CGSize) {
        guard let window = windows[id] else { return }
        
        let aspectRatio = window.imageAspectRatio
        let maxSize = window.originalImageSize
        var frame = window.frame
        
        // Determine resize direction based on corner
        let deltaWidth: CGFloat
        let anchorRight: Bool
        let anchorTop: Bool
        
        switch corner {
        case .topLeft:
            deltaWidth = -delta.width
            anchorRight = true
            anchorTop = false
        case .topRight:
            deltaWidth = delta.width
            anchorRight = false
            anchorTop = false
        case .bottomLeft:
            deltaWidth = -delta.width
            anchorRight = true
            anchorTop = true
        case .bottomRight:
            deltaWidth = delta.width
            anchorRight = false
            anchorTop = true
        }
        
        // Calculate new width maintaining aspect ratio
        var newWidth = frame.width + deltaWidth
        
        // Enforce both min width and min height (same value), and cap by original size on both axes.
        let minWidth: CGFloat = 175
        let minHeight: CGFloat = 175
        
        // Convert min/max constraints to width space using aspect ratio
        let effectiveMinWidth = max(minWidth, minHeight * aspectRatio)
        let effectiveMaxWidth = min(maxSize.width, maxSize.height * aspectRatio)
        
        newWidth = max(effectiveMinWidth, min(newWidth, effectiveMaxWidth))
        let newHeight = newWidth / aspectRatio
        
        // Calculate new origin based on anchor
        if anchorRight {
            frame.origin.x = frame.origin.x + frame.width - newWidth
        }
        if anchorTop {
            // Keep top edge fixed (in macOS coordinates, top = origin.y + height)
            frame.origin.y = frame.origin.y + frame.height - newHeight
        }
        
        frame.size = NSSize(width: newWidth, height: newHeight)
        window.setFrame(frame, display: true, animate: false)
    }
}

// MARK: - Popout Panel

final class PopoutImagePanel: NSPanel {
    var imageAspectRatio: CGFloat = 1.0
    var originalImageSize: NSSize = NSSize(width: 400, height: 400)
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Popout Image View

struct PopoutImageView: View {
    let image: NSImage
    let title: String
    let onClose: () -> Void
    let onModeChanged: (PopoutWindowMode) -> Void
    let onResizeTopLeft: (CGSize) -> Void
    let onResizeTopRight: (CGSize) -> Void
    let onResizeBottomLeft: (CGSize) -> Void
    let onResizeBottomRight: (CGSize) -> Void
    
    @State private var currentMode: PopoutWindowMode = .drag
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            // Main image
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                // shadow removed
                //.shadow(color: .black.opacity(0.3), radius: 15, y: 8)
            
            // Mode indicators (always visible when in that mode)
            modeIndicators
            
            // Controls (visible on hover)
            if isHovered {
                controlsOverlay
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.2), value: currentMode)
    }
    
    // MARK: - Mode Indicators
    
    @ViewBuilder
    private var modeIndicators: some View {
        switch currentMode {
        case .drag:
            dragIndicator
        case .resize:
            resizeHandles
        case .locked:
            lockedIndicator
        }
    }
    
    // Subtle drag indicator - small icon in bottom right
    private var dragIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(systemName: "hand.draw")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(8)
            }
        }
        .allowsHitTesting(false)
    }
    
    // Corner handles - one in each corner
    private var resizeHandles: some View {
        ZStack {
            // Top-left
            VStack {
                HStack {
                    ResizeCornerHandle(corner: .topLeft)
                        .gesture(resizeGesture(for: .topLeft))
                    Spacer()
                }
                Spacer()
            }
            
            // Top-right
            VStack {
                HStack {
                    Spacer()
                    ResizeCornerHandle(corner: .topRight)
                        .gesture(resizeGesture(for: .topRight))
                }
                Spacer()
            }
            
            // Bottom-left
            VStack {
                Spacer()
                HStack {
                    ResizeCornerHandle(corner: .bottomLeft)
                        .gesture(resizeGesture(for: .bottomLeft))
                    Spacer()
                }
            }
            
            // Bottom-right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ResizeCornerHandle(corner: .bottomRight)
                        .gesture(resizeGesture(for: .bottomRight))
                }
            }
        }
    }
    
    // Locked indicator - subtle lock overlay
    private var lockedIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(8)
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Controls Overlay
    
    private var controlsOverlay: some View {
        HStack {
            // Left side - vertical toolbar
            VStack(spacing: 4) {
                // Mode buttons
                ForEach(PopoutWindowMode.allCases, id: \.self) { mode in
                    ModeButton(
                        mode: mode,
                        isSelected: currentMode == mode,
                        action: {
                            currentMode = mode
                            onModeChanged(mode)
                        }
                    )
                }
                
                Spacer()
                    .frame(height: 8)
                
                // Close button
                CloseButton(action: onClose)
            }
            .padding(8)
            
            Spacer()
        }
        .transition(.opacity)
    }
    
    // MARK: - Resize Gesture
    
    private func resizeGesture(for corner: ResizeCorner) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let delta = CGSize(width: value.translation.width, height: value.translation.height)
                switch corner {
                case .topLeft: onResizeTopLeft(delta)
                case .topRight: onResizeTopRight(delta)
                case .bottomLeft: onResizeBottomLeft(delta)
                case .bottomRight: onResizeBottomRight(delta)
                }
            }
    }
}

// MARK: - Supporting Types

enum ResizeCorner {
    case topLeft, topRight, bottomLeft, bottomRight
}

// MARK: - Component Views

struct ModeButton: View {
    let mode: PopoutWindowMode
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? mode.activeIcon : mode.icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(foregroundColor)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(backgroundColor)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    private var foregroundColor: Color {
        if isSelected { return .white }
        if isHovered { return .white }
        return .white.opacity(0.7)
    }
    
    private var backgroundColor: Color {
        if isSelected { return .white.opacity(0.25) }
        if isHovered { return .black.opacity(0.7) }
        return .black.opacity(0.5)
    }
}

struct CloseButton: View {
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isHovered ? .white : .white.opacity(0.8))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? .black.opacity(0.8) : .black.opacity(0.5))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct ResizeCornerHandle: View {
    let corner: ResizeCorner
    
    @State private var isHovered = false
    
    var body: some View {
        Canvas { context, size in
            let lineWidth: CGFloat = 3
            let armLength: CGFloat = 14
            let inset: CGFloat = 6
            let color = isHovered ? Color.white : Color.white.opacity(0.5)
            
            var path = Path()
            
            switch corner {
            case .topLeft:
                path.move(to: CGPoint(x: inset, y: inset + armLength))
                path.addLine(to: CGPoint(x: inset, y: inset))
                path.addLine(to: CGPoint(x: inset + armLength, y: inset))
                
            case .topRight:
                path.move(to: CGPoint(x: size.width - inset - armLength, y: inset))
                path.addLine(to: CGPoint(x: size.width - inset, y: inset))
                path.addLine(to: CGPoint(x: size.width - inset, y: inset + armLength))
                
            case .bottomLeft:
                path.move(to: CGPoint(x: inset, y: size.height - inset - armLength))
                path.addLine(to: CGPoint(x: inset, y: size.height - inset))
                path.addLine(to: CGPoint(x: inset + armLength, y: size.height - inset))
                
            case .bottomRight:
                path.move(to: CGPoint(x: size.width - inset - armLength, y: size.height - inset))
                path.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
                path.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset - armLength))
            }
            
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
