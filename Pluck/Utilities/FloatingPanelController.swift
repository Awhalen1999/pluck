//
//  FloatingPanelController.swift
//  Pluck
//
//  Creates and manages the floating panel window.
//  Responds to state changes by animating the window frame.
//  Singleton with proper memory management and thread safety.
//

import AppKit
import SwiftUI
import SwiftData

// MARK: - Floating Panel

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Controller

@MainActor
final class FloatingPanelController {
    
    // MARK: - Singleton
    
    static let shared = FloatingPanelController()
    
    // MARK: - Public Properties
    
    let windowManager: WindowManager
    let clipboardWatcher: ClipboardWatcher
    private(set) lazy var pasteController = PasteController(
        windowManager: windowManager,
        clipboardWatcher: clipboardWatcher
    )
    
    // MARK: - Private Properties
    
    private var panel: FloatingPanel?
    private var stateObserver: NSObjectProtocol?
    private var windowActiveObserver: NSObjectProtocol?
    private var windowResignObserver: NSObjectProtocol?
    private var modelContainer: ModelContainer?
    
    // State tracking for animations
    private var lastDockedEdge: DockedEdge?
    private var lastPanelState: PanelState?
    
    // MARK: - Configuration
    
    private enum Config {
        static let animationDuration: TimeInterval = 0.3
        static let animationTiming = CAMediaTimingFunction(name: .easeInEaseOut)
    }
    
    // MARK: - Initialization
    
    private init() {
        self.windowManager = WindowManager()
        self.clipboardWatcher = ClipboardWatcher()
        
        setupModelContainer()
        observeStateChanges()
        clipboardWatcher.startWatching()
        
        Log.info("FloatingPanelController initialized", subsystem: .window)
    }
    
    // MARK: - Model Container Setup
    
    private func setupModelContainer() {
        do {
            let storeURL = try FileManagerHelper.appSupportDirectory.appendingPathComponent("Pluck.store")
            let config = ModelConfiguration(url: storeURL)
            modelContainer = try ModelContainer(
                for: DesignFolder.self, DesignImage.self,
                configurations: config
            )
            Log.info("ModelContainer created at: \(storeURL.path)", subsystem: .data)
        } catch {
            Log.critical("Failed to create ModelContainer", error: error, subsystem: .data)
            // App can still run but data won't persist
        }
    }
    
    // MARK: - Observers
    
    private func observeStateChanges() {
        // Panel state changes
        stateObserver = NotificationCenter.default.addObserver(
            forName: .panelStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.animateToCurrentState()
        }
        
        // Window became key
        windowActiveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let window = notification.object as? FloatingPanel,
                  window === self.panel else { return }
            self.windowManager.isWindowActive = true
            Log.debug("Panel became key window", subsystem: .window)
        }
        
        // Window resigned key
        windowResignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let window = notification.object as? FloatingPanel,
                  window === self.panel else { return }
            self.windowManager.isWindowActive = false
            Log.debug("Panel resigned key window", subsystem: .window)
        }
    }
    
    private func removeObservers() {
        if let observer = stateObserver {
            NotificationCenter.default.removeObserver(observer)
            stateObserver = nil
        }
        if let observer = windowActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            windowActiveObserver = nil
        }
        if let observer = windowResignObserver {
            NotificationCenter.default.removeObserver(observer)
            windowResignObserver = nil
        }
    }
    
    // MARK: - Public API
    
    func showPanel() {
        if let panel {
            panel.orderFront(nil)
            Log.debug("Panel brought to front", subsystem: .window)
            return
        }
        createPanel()
    }
    
    func hidePanel() {
        panel?.orderOut(nil)
        Log.debug("Panel hidden", subsystem: .window)
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
    
    var isPanelVisible: Bool {
        panel?.isVisible ?? false
    }
    
    // MARK: - Panel Creation
    
    private func createPanel() {
        guard let screen = NSScreen.main else {
            Log.error("No main screen available", subsystem: .window)
            return
        }
        
        // Initialize state tracking
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
        
        Log.info("Panel created at frame: \(frame)", subsystem: .window)
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
            .environment(pasteController)
        
        if let modelContainer {
            let view = content.modelContainer(modelContainer)
            panel.contentView = NSHostingView(rootView: view)
        } else {
            // Fallback without model container (data won't persist)
            Log.warning("Attaching content without ModelContainer", subsystem: .window)
            panel.contentView = NSHostingView(rootView: content)
        }
    }
    
    // MARK: - Frame Animation
    
    private func animateToCurrentState() {
        guard let panel, let screen = NSScreen.main else {
            Log.warning("Cannot animate: panel or screen unavailable", subsystem: .window)
            return
        }
        
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
            // Instant teleport for edge switch (no animation)
            Log.debug("Edge changed - teleporting to new position", subsystem: .window)
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0
            panel.setFrame(newFrame, display: true)
            NSAnimationContext.endGrouping()
        } else {
            // Animated transition for open/close
            Log.debug("Animating to state: \(windowManager.panelState)", subsystem: .window)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Config.animationDuration
                context.timingFunction = Config.animationTiming
                panel.animator().setFrame(newFrame, display: true)
            }
        }
    }
    
    private func calculateYFromTop(panel: FloatingPanel, screen: NSScreen) -> CGFloat {
        let screenRect = screen.visibleFrame
        return screenRect.maxY - panel.frame.origin.y - panel.frame.height
    }
}
