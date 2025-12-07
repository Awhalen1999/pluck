//
//  FloatingPanelController.swift
//  Pluck
//

import AppKit
import SwiftUI
import SwiftData

// MARK: - Floating Panel

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Panel Controller

@MainActor
class FloatingPanelController {
    static let shared = FloatingPanelController()
    
    private var panel: FloatingPanel?
    let windowManager = WindowManager()
    private var modelContainer: ModelContainer?
    
    private let edgeMargin: CGFloat = 10
    
    private enum PanelSize {
        static let collapsed = NSSize(width: 50, height: 50)
        static let folderList = NSSize(width: 220, height: 350)
        static let folderOpen = NSSize(width: 240, height: 340)
        static let imageFocused = NSSize(width: 360, height: 420)
    }
    
    private init() {
        setupModelContainer()
        setupNotificationObserver()
    }
    
    private func setupModelContainer() {
        do {
            modelContainer = try ModelContainer(for: DesignFolder.self, DesignImage.self)
        } catch {
            print("Failed to create ModelContainer: \(error)")
        }
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .panelStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updatePanelFrame()
            }
        }
    }
    
    func showPanel() {
        if let panel = panel {
            panel.orderFront(nil)
            return
        }
        createPanel()
    }
    
    func hidePanel() {
        panel?.orderOut(nil)
    }
    
    func togglePanel() {
        if let panel = panel, panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }
    
    private func createPanel() {
        guard let modelContainer = modelContainer else { return }
        
        let contentView = FloatingPanelView()
            .environment(windowManager)
            .modelContainer(modelContainer)
        
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: PanelSize.collapsed),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        
        // Set initial position based on docked edge
        if let screen = NSScreen.main {
            let origin = calculateOrigin(
                for: PanelSize.collapsed,
                in: screen.visibleFrame
            )
            panel.setFrameOrigin(origin)
        }
        
        panel.contentView = NSHostingView(rootView: contentView)
        panel.orderFront(nil)
        
        self.panel = panel
    }
    
    func updatePanelFrame(animated: Bool = false) {
        guard let panel = panel, let screen = NSScreen.main else { return }
        
        let newSize = sizeForCurrentState()
        let screenRect = screen.visibleFrame
        let newOrigin = calculateOrigin(for: newSize, in: screenRect)
        let newFrame = NSRect(origin: newOrigin, size: newSize)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
        }
    }
    
    private func calculateOrigin(for size: NSSize, in screenRect: NSRect) -> NSPoint {
        let x: CGFloat
        
        if windowManager.dockedEdge == .right {
            x = screenRect.maxX - size.width - edgeMargin
        } else {
            x = screenRect.minX + edgeMargin
        }
        
        // Y position: convert from "distance from top" to screen coordinates
        let y = screenRect.maxY - windowManager.dockedYPosition - size.height
        
        // Clamp Y to keep panel on screen
        let clampedY = max(screenRect.minY + edgeMargin, min(y, screenRect.maxY - size.height - edgeMargin))
        
        return NSPoint(x: x, y: clampedY)
    }
    
    private func sizeForCurrentState() -> NSSize {
        switch windowManager.panelState {
        case .collapsed: return PanelSize.collapsed
        case .folderList: return PanelSize.folderList
        case .folderOpen: return PanelSize.folderOpen
        case .imageFocused: return PanelSize.imageFocused
        }
    }
}
