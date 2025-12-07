//
//  FloatingPanelController.swift
//  Pluck
//

import AppKit
import SwiftUI
import SwiftData

// MARK: - FloatingPanel

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - FloatingPanelController

@MainActor
final class FloatingPanelController {
    
    static let shared = FloatingPanelController()
    
    // MARK: - Configuration
    
    private enum Layout {
        static let edgeMargin: CGFloat = 10
        
        static let collapsedSize = NSSize(width: 50, height: 50)
        static let folderListSize = NSSize(width: 220, height: 350)
        static let folderOpenSize = NSSize(width: 220, height: 350)
        static let imageFocusedSize = NSSize(width: 340, height: 400)
    }
    
    // MARK: - Properties
    
    let windowManager = WindowManager()
    
    private var panel: FloatingPanel?
    private var modelContainer: ModelContainer?
    private var stateObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    private init() {
        setupModelContainer()
        setupStateObserver()
    }
    
    deinit {
        if let observer = stateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupModelContainer() {
        do {
            modelContainer = try ModelContainer(for: DesignFolder.self, DesignImage.self)
        } catch {
            assertionFailure("Failed to create ModelContainer: \(error)")
        }
    }
    
    private func setupStateObserver() {
        stateObserver = NotificationCenter.default.addObserver(
            forName: .panelStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updatePanelFrame()
            }
        }
    }
    
    // MARK: - Panel Visibility
    
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
        guard let panel = panel, panel.isVisible else {
            showPanel()
            return
        }
        hidePanel()
    }
    
    // MARK: - Panel Creation
    
    private func createPanel() {
        guard let modelContainer = modelContainer else { return }
        
        let contentView = FloatingPanelView()
            .environment(windowManager)
            .modelContainer(modelContainer)
        
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: Layout.collapsedSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        configurePanel(panel)
        positionPanel(panel, size: Layout.collapsedSize)
        
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
    
    private func positionPanel(_ panel: FloatingPanel, size: NSSize) {
        guard let screen = NSScreen.main else { return }
        let origin = calculateOrigin(for: size, in: screen.visibleFrame)
        panel.setFrameOrigin(origin)
    }
    
    // MARK: - Frame Updates
    
    func updatePanelFrame(animated: Bool = false) {
        guard let panel = panel, let screen = NSScreen.main else { return }
        
        let newSize = sizeForCurrentState()
        let newOrigin = calculateOrigin(for: newSize, in: screen.visibleFrame)
        let newFrame = NSRect(origin: newOrigin, size: newSize)
        
        guard animated else {
            panel.setFrame(newFrame, display: true)
            return
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(newFrame, display: true)
        }
    }
    
    // MARK: - Layout Calculation
    
    private func calculateOrigin(for size: NSSize, in screenRect: NSRect) -> NSPoint {
        let x: CGFloat
        if windowManager.dockedEdge == .right {
            x = screenRect.maxX - size.width - Layout.edgeMargin
        } else {
            x = screenRect.minX + Layout.edgeMargin
        }
        
        let y = screenRect.maxY - windowManager.dockedYPosition - size.height
        let clampedY = y.clamped(to: screenRect.minY + Layout.edgeMargin...screenRect.maxY - size.height - Layout.edgeMargin)
        
        return NSPoint(x: x, y: clampedY)
    }
    
    private func sizeForCurrentState() -> NSSize {
        switch windowManager.panelState {
        case .collapsed: return Layout.collapsedSize
        case .folderList: return Layout.folderListSize
        case .folderOpen: return Layout.folderOpenSize
        case .imageFocused: return Layout.imageFocusedSize
        }
    }
}

// MARK: - Comparable Extension

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
