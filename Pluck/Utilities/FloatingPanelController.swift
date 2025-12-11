//
//  FloatingPanelController.swift
//  Pluck
//
//  Creates and manages the floating panel window.
//  Responds to state changes by animating the window frame.
//

import AppKit
import SwiftUI

// MARK: - Floating Panel

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Controller

@MainActor
final class FloatingPanelController {
    
    static let shared = FloatingPanelController()
    
    // MARK: - Properties
    
    let windowManager = WindowManager()
    
    private var panel: FloatingPanel?
    private var stateObserver: NSObjectProtocol?
    
    // MARK: - Animation Configuration
    
    private let animationDuration: TimeInterval = 0.3
    private let animationTiming = CAMediaTimingFunction(name: .easeInEaseOut)
    
    // MARK: - Init
    
    private init() {
        observeStateChanges()
    }
    
    private func observeStateChanges() {
        stateObserver = NotificationCenter.default.addObserver(
            forName: .panelStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.animateToCurrentState()
            }
        }
    }
    
    // MARK: - Public
    
    func showPanel() {
        if let panel {
            panel.orderFront(nil)
            return
        }
        createPanel()
    }
    
    func hidePanel() {
        panel?.orderOut(nil)
    }
    
    func togglePanel() {
        guard let panel else {
            showPanel()
            return
        }
        
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }
    
    // MARK: - Panel Creation
    
    private func createPanel() {
        guard let screen = NSScreen.main else { return }
        
        // Initialize edge tracking
        lastDockedEdge = windowManager.dockedEdge
        lastPanelState = windowManager.panelState
        
        let frame = PanelDimensions.calculateFrame(
            for: .closed,
            dockedEdge: windowManager.dockedEdge,
            yFromTop: windowManager.dockedYPosition,
            screen: screen
        )
        
        let panel = FloatingPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        configurePanel(panel)
        attachContent(to: panel)
        
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
    
    private func attachContent(to panel: FloatingPanel) {
        let content = PluckViewCoordinator()
            .environment(windowManager)
        
        panel.contentView = NSHostingView(rootView: content)
    }
    
    // MARK: - Frame Updates
    
    private var lastDockedEdge: DockedEdge?
    private var lastPanelState: PanelState?
    
    private func animateToCurrentState() {
        guard let panel, let screen = NSScreen.main else { return }
        
        // Detect what changed
        let edgeChanged = lastDockedEdge != nil && lastDockedEdge != windowManager.dockedEdge
        
        // Update tracking
        lastDockedEdge = windowManager.dockedEdge
        lastPanelState = windowManager.panelState
        
        // Preserve Y position
        let currentYFromTop = calculateYFromTop(panel: panel, screen: screen)
        windowManager.updateYPosition(currentYFromTop)
        
        let newFrame = PanelDimensions.calculateFrame(
            for: windowManager.panelState,
            dockedEdge: windowManager.dockedEdge,
            yFromTop: windowManager.dockedYPosition,
            screen: screen
        )
        
        if edgeChanged {
            // Teleport instantly for edge switch - no animation
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0
            panel.setFrame(newFrame, display: true)
            NSAnimationContext.endGrouping()
        } else {
            // Animate for open/close
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                context.timingFunction = animationTiming
                panel.animator().setFrame(newFrame, display: true)
            }
        }
    }
    
    private func calculateYFromTop(panel: FloatingPanel, screen: NSScreen) -> CGFloat {
        let screenRect = screen.visibleFrame
        return screenRect.maxY - panel.frame.origin.y - panel.frame.height
    }
}
