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
    
    // MARK: - Panel Sizes
    
    private enum PanelSize {
        static let collapsed = NSSize(width: 50, height: 50)
        static let folderList = NSSize(width: 280, height: 350)
        static let folderOpen = NSSize(width: 280, height: 350)
        static let imageFocused = NSSize(width: 400, height: 450)
    }
    
    // MARK: - Init
    
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
    
    // MARK: - Panel Management
    
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
    
    // MARK: - Private Methods
    
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
        
        configurePanel(panel)
        positionPanel(panel)
        
        panel.contentView = NSHostingView(rootView: contentView)
        panel.orderFront(nil)
        
        self.panel = panel
    }
    
    private func configurePanel(_ panel: FloatingPanel) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
    }
    
    private func positionPanel(_ panel: FloatingPanel) {
        guard let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let x = screenRect.maxX - 80
        let y = screenRect.maxY - 80
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func updatePanelSize() {
        guard let panel = panel else { return }
        
        let newSize = sizeForCurrentState()
        
        var frame = panel.frame
        let anchorPoint = NSPoint(x: frame.maxX, y: frame.maxY)
        frame.size = newSize
        frame.origin = NSPoint(
            x: anchorPoint.x - newSize.width,
            y: anchorPoint.y - newSize.height
        )
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
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
