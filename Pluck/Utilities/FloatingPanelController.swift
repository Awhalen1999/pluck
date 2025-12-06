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
    
    private var expandedLeft: Bool = true
    private var collapsedOrigin: NSPoint?
    
    private enum PanelSize {
        static let collapsed = NSSize(width: 50, height: 50)
        static let folderList = NSSize(width: 280, height: 350)
        static let folderOpen = NSSize(width: 280, height: 350)
        static let imageFocused = NSSize(width: 400, height: 450)
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
                self?.updatePanelSize()
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
        
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.maxX - 80
            let y = screenRect.maxY - 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        panel.contentView = NSHostingView(rootView: contentView)
        panel.orderFront(nil)
        
        self.panel = panel
    }
    
    private var lastUpdateSize: CGFloat = 50
    
    func updatePanelSize() {
        guard let panel = panel, let screen = NSScreen.main else { return }
        
        let currentFrame = panel.frame
        let newSize = sizeForCurrentState()
        let screenRect = screen.visibleFrame
        
        // Skip duplicate calls
        if newSize.width == lastUpdateSize {
            return
        }
        lastUpdateSize = newSize.width
        
        let wasCollapsed = currentFrame.size.width <= 100
        let isCollapsing = newSize.width <= 100
        let isExpanding = newSize.width > 100
        
        // Save collapsed position before expanding
        if wasCollapsed && isExpanding {
            collapsedOrigin = currentFrame.origin
            
            let panelCenterX = currentFrame.midX
            let screenCenterX = screenRect.midX
            expandedLeft = panelCenterX > screenCenterX
        }
        
        var newOrigin: NSPoint
        
        // When collapsing, restore the exact saved position
        if isCollapsing, let savedOrigin = collapsedOrigin {
            newOrigin = savedOrigin
        } else if expandedLeft {
            newOrigin = NSPoint(
                x: currentFrame.maxX - newSize.width,
                y: currentFrame.maxY - newSize.height
            )
        } else {
            newOrigin = NSPoint(
                x: currentFrame.minX,
                y: currentFrame.maxY - newSize.height
            )
        }
        
        panel.setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
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
