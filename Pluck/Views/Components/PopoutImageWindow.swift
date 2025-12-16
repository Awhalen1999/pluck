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

@MainActor @Observable
final class PopoutWindowManager {
    static let shared = PopoutWindowManager()
    
    private var windows: [UUID: PopoutImagePanel] = [:]
    
    /// Tracks which DesignImage IDs are currently open in popout windows
    private(set) var openImageIDs: Set<UUID> = []
    
    private init() {}
    
    func openImage(_ image: DesignImage) {
        guard let nsImage = FileManagerHelper.loadImage(filename: image.filename) else { return }
        
        let windowID = UUID()
        let imageID = image.id
        
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
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.imageAspectRatio = imageSize.width / imageSize.height
        window.originalImageSize = imageSize
        window.designImageID = imageID  // Store the image ID in the window
        
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
        openImageIDs.insert(imageID)
    }
    
    /// Check if a specific image is currently open in a popout window
    func isImageOpen(_ imageID: UUID) -> Bool {
        openImageIDs.contains(imageID)
    }
    
    /// Close the popout window for a specific image
    func closeImage(_ imageID: UUID) {
        guard let (windowID, _) = windows.first(where: { $0.value.designImageID == imageID }) else { return }
        closeWindow(id: windowID)
    }
    
    private func closeWindow(id: UUID) {
        if let window = windows[id], let imageID = window.designImageID {
            openImageIDs.remove(imageID)
        }
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
        
        // Proposed new width maintaining aspect ratio
        var newWidth = frame.width + deltaWidth
        
        // Robust constraints:
        // - Minimums: never let the window go below these (one-way bridge).
        // - Maximums: generous, based on screen visible frame, so users can always grow.
        let minWidth: CGFloat = 175
        let minHeight: CGFloat = 175
        
        // Compute effective min/max in width-space
        let effectiveMinWidth = max(minWidth, minHeight * aspectRatio)
        
        // Screen-based maximum (use 90% of visible frame)
        let screenSize = NSScreen.main?.visibleFrame.size ?? NSSize(width: 4000, height: 4000)
        let screenMaxWidth = screenSize.width * 0.9
        let screenMaxHeightAsWidth = screenSize.height * aspectRatio * 0.9
        let effectiveMaxWidth = max(200, min(screenMaxWidth, screenMaxHeightAsWidth))
        
        newWidth = max(effectiveMinWidth, min(newWidth, effectiveMaxWidth))
        let newHeight = newWidth / aspectRatio
        
        // Re-anchor origin so the opposite corner stays fixed
        if anchorRight {
            frame.origin.x = frame.origin.x + frame.width - newWidth
        }
        if anchorTop {
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
    var designImageID: UUID?  // Track which DesignImage this window displays
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Popout Image View

private enum OverlayContrastStyle {
    case lightOnDark   // white primary with dark halo
    case darkOnLight   // dark primary with light halo
}

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
    @State private var overlayStyle: OverlayContrastStyle = .lightOnDark
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Image
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Controls overlay (visible on hover)
                if isHovered {
                    controlsOverlay
                }
                
                // Resize handles (only in resize mode)
                if currentMode == .resize {
                    resizeHandles(style: overlayStyle)
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
        .onAppear {
            // Determine overlay style based on image luminance
            let luminance = image.averageLuminanceFast()
            overlayStyle = luminance > 0.5 ? .darkOnLight : .lightOnDark
        }
    }
    
    // MARK: - Resize Handles
    
    @ViewBuilder
    private func resizeHandles(style: OverlayContrastStyle) -> some View {
        // Top-left
        VStack {
            HStack {
                ResizeCornerHandle(corner: .topLeft, style: style)
                    .gesture(resizeGesture(for: .topLeft))
                Spacer()
            }
            Spacer()
        }
        
        // Top-right
        VStack {
            HStack {
                Spacer()
                ResizeCornerHandle(corner: .topRight, style: style)
                    .gesture(resizeGesture(for: .topRight))
            }
            Spacer()
        }
        
        // Bottom-left
        VStack {
            Spacer()
            HStack {
                ResizeCornerHandle(corner: .bottomLeft, style: style)
                    .gesture(resizeGesture(for: .bottomLeft))
                Spacer()
            }
        }
        
        // Bottom-right
        VStack {
            Spacer()
            HStack {
                Spacer()
                ResizeCornerHandle(corner: .bottomRight, style: style)
                    .gesture(resizeGesture(for: .bottomRight))
            }
        }
    }
    
    // MARK: - Controls Overlay
    
    private var controlsOverlay: some View {
        HStack {
            VStack(spacing: 4) {
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
                
                Spacer().frame(height: 8)
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
    
    private var baseBG: Color { .black.opacity(0.5) }
    private var hoverBG: Color { .black.opacity(0.7) }
    private var selectedBG: Color { .black.opacity(0.8) } // darker gray when selected
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? mode.activeIcon : mode.icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isSelected ? .white : (isHovered ? .white : .white.opacity(0.7)))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? selectedBG : (isHovered ? hoverBG : baseBG))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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

fileprivate struct ResizeCornerHandle: View {
    let corner: ResizeCorner
    let style: OverlayContrastStyle
    
    @State private var isHovered = false
    
    var body: some View {
        let fg: Color
        let halo: Color
        
        switch style {
        case .lightOnDark:
            fg = .white
            halo = .black.opacity(0.35)
        case .darkOnLight:
            fg = .black.opacity(0.9)
            halo = .white.opacity(0.7)
        }
        
        return Canvas { context, size in
            let lineWidth: CGFloat = 3
            let armLength: CGFloat = 14
            let inset: CGFloat = 6
            
            // Halo (slightly thicker)
            var haloPath = Path()
            switch corner {
            case .topLeft:
                haloPath.move(to: CGPoint(x: inset, y: inset + armLength))
                haloPath.addLine(to: CGPoint(x: inset, y: inset))
                haloPath.addLine(to: CGPoint(x: inset + armLength, y: inset))
            case .topRight:
                haloPath.move(to: CGPoint(x: size.width - inset - armLength, y: inset))
                haloPath.addLine(to: CGPoint(x: size.width - inset, y: inset))
                haloPath.addLine(to: CGPoint(x: size.width - inset, y: inset + armLength))
            case .bottomLeft:
                haloPath.move(to: CGPoint(x: inset, y: size.height - inset - armLength))
                haloPath.addLine(to: CGPoint(x: inset, y: size.height - inset))
                haloPath.addLine(to: CGPoint(x: inset + armLength, y: size.height - inset))
            case .bottomRight:
                haloPath.move(to: CGPoint(x: size.width - inset - armLength, y: size.height - inset))
                haloPath.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
                haloPath.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset - armLength))
            }
            context.stroke(
                haloPath,
                with: .color(halo.opacity(isHovered ? 0.35 : 0.25)),
                style: StrokeStyle(lineWidth: lineWidth + 2, lineCap: .round, lineJoin: .round)
            )
            
            // Foreground stroke
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
            context.stroke(
                path,
                with: .color(fg.opacity(isHovered ? 1.0 : 0.95)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - NSImage Average Luminance (fast)

private extension NSImage {
    func averageLuminanceFast(sampleSize: Int = 16) -> CGFloat {
        // Downscale to small bitmap, average luma (Rec. 709)
        let targetSize = NSSize(width: sampleSize, height: sampleSize)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetSize.width),
            pixelsHigh: Int(targetSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return 0.0 }
        
        let ctx = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        NSColor.clear.set()
        NSRect(origin: .zero, size: targetSize).fill()
        draw(in: NSRect(origin: .zero, size: targetSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy,
             fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()
        
        guard let data = rep.bitmapData else { return 0.0 }
        let count = Int(targetSize.width * targetSize.height)
        var sum: CGFloat = 0
        
        for i in 0..<count {
            let offset = i * 4
            let r = CGFloat(data[offset + 0]) / 255.0
            let g = CGFloat(data[offset + 1]) / 255.0
            let b = CGFloat(data[offset + 2]) / 255.0
            // Rec. 709 luma
            let y = 0.2126 * r + 0.7152 * g + 0.0722 * b
            sum += y
        }
        return max(0, min(1, sum / CGFloat(count)))
    }
}
