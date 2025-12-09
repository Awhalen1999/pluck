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
    private var heightObserver: NSObjectProtocol?
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
            Task { @MainActor in
                self?.updatePanelFrame(animated: false)
            }
        }
        
        heightObserver = NotificationCenter.default.addObserver(
            forName: .panelHeightChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updatePanelFrame(animated: true)
            }
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
        
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: PanelDimensions.collapsedNSSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        configurePanel(panel)
        positionPanel(panel, size: PanelDimensions.collapsedNSSize)
        
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
            x = screenRect.maxX - size.width - PanelDimensions.edgeMargin
        } else {
            x = screenRect.minX + PanelDimensions.edgeMargin
        }
        
        let y = screenRect.maxY - windowManager.dockedYPosition - size.height
        let clampedY = y.clamped(to: screenRect.minY + PanelDimensions.edgeMargin...screenRect.maxY - size.height - PanelDimensions.edgeMargin)
        
        return NSPoint(x: x, y: clampedY)
    }
    
    private func sizeForCurrentState() -> NSSize {
        switch windowManager.panelState {
        case .collapsed:
            return PanelDimensions.collapsedNSSize
            
        case .folderList, .folderOpen:
            let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
            let height = PanelDimensions.listHeight(
                expanded: windowManager.isHeightExpanded,
                screenHeight: screenHeight
            )
            return NSSize(width: PanelDimensions.folderListSize.width, height: height)
            
        case .imageFocused:
            return PanelDimensions.imageDetailNSSize
        }
    }
}
