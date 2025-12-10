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
    
    // MARK: - Properties
    
    let windowManager = WindowManager()
    let clipboardWatcher = ClipboardWatcher()
    let pasteController: PasteController
    
    private var panel: FloatingPanel?
    private var modelContainer: ModelContainer?
    private var stateObserver: NSObjectProtocol?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var windowFocusObservers: [NSObjectProtocol] = []
    
    // MARK: - Initialization
    
    private init() {
        self.pasteController = PasteController(
            windowManager: windowManager,
            clipboardWatcher: clipboardWatcher
        )
        
        setupModelContainer()
        setupObservers()
        setupKeyMonitors()
        setupWindowFocusObservers()
    }
    
    // MARK: - Model Container
    
    private func setupModelContainer() {
        do {
            let storeURL = FileManagerHelper.appSupportDirectory.appendingPathComponent("Pluck.store")
            let config = ModelConfiguration(url: storeURL)
            
            modelContainer = try ModelContainer(
                for: DesignFolder.self, DesignImage.self,
                configurations: config
            )
            pasteController.setModelContainer(modelContainer!)
        } catch {
            assertionFailure("Failed to create ModelContainer: \(error)")
        }
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        stateObserver = NotificationCenter.default.addObserver(
            forName: .panelStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updatePanelFrame(animated: false)
        }
    }

    // MARK: - Window Focus

    private func setupWindowFocusObservers() {
        let becameKey = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      let window = notification.object as? NSWindow,
                      window === self.panel else { return }
                self.windowManager.isWindowActive = true
            }
        }
        
        let resignedKey = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      let window = notification.object as? NSWindow,
                      window === self.panel else { return }
                self.windowManager.isWindowActive = false
            }
        }
        
        windowFocusObservers = [becameKey, resignedKey]
    }
    
    // MARK: - Key Monitors
    
    private func setupKeyMonitors() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleKeyEvent(event)
        }
        
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              event.charactersIgnoringModifiers == "v" else { return false }
        
        guard isMouseOverPanel() else { return false }
        
        return pasteController.handlePaste()
    }
    
    private func isMouseOverPanel() -> Bool {
        guard let panel = panel else { return false }
        let mouseLocation = NSEvent.mouseLocation
        return panel.frame.contains(mouseLocation)
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
            .environment(clipboardWatcher)
            .environment(pasteController)
            .modelContainer(modelContainer)
        
        guard let screen = NSScreen.main else { return }
        
        // Use unified sizing system for initial frame
        let initialFrame = PanelDimensions.calculateFrame(
            for: .collapsed,
            dockedEdge: windowManager.dockedEdge,
            yFromTop: windowManager.dockedYPosition,
            screen: screen
        )
        
        let panel = FloatingPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        configurePanel(panel)
        
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
    
    // MARK: - Frame Updates
    
    func updatePanelFrame(animated: Bool = false) {
        guard let panel = panel, let screen = NSScreen.main else { return }
        
        // IMPORTANT: Capture current Y position before resizing
        // This prevents jumps when transitioning between states
        let currentFrame = panel.frame
        let screenRect = screen.visibleFrame
        let currentYFromTop = screenRect.maxY - currentFrame.origin.y - currentFrame.height
        windowManager.dockedYPosition = currentYFromTop
        
        // Use unified sizing system
        let newFrame = PanelDimensions.calculateFrame(
            for: windowManager.panelState,
            dockedEdge: windowManager.dockedEdge,
            yFromTop: windowManager.dockedYPosition,
            screen: screen
        )
        
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
}
