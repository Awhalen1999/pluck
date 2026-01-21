//
//  WindowManager.swift
//  Pluck
//
//  Central state manager for panel open/close behavior.
//  Thread-safe, validated, with proper notification handling.
//

import Foundation

// MARK: - Panel State

enum PanelState: Equatable, CustomStringConvertible {
    case closed
    case open
    
    var description: String {
        switch self {
        case .closed: return "closed"
        case .open: return "open"
        }
    }
}

// MARK: - Docked Edge

enum DockedEdge: String, CaseIterable {
    case left
    case right
    
    var opposite: DockedEdge {
        switch self {
        case .left: return .right
        case .right: return .left
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let panelStateChanged = Notification.Name("com.pluck.panelStateChanged")
}

// MARK: - Window Manager

@Observable
@MainActor
final class WindowManager {
    
    // MARK: - Constants
    
    private enum Defaults {
        static let dockedEdge: DockedEdge = .right
        static let yPosition: CGFloat = 200
        static let minYPosition: CGFloat = 0
        static let maxYPosition: CGFloat = 10000  // Reasonable upper bound
    }
    
    // MARK: - Persisted Keys
    
    private enum UserDefaultsKey {
        static let dockedEdge = "pluck.dockedEdge"
        static let yPosition = "pluck.yPosition"
    }
    
    // MARK: - State
    
    private(set) var panelState: PanelState = .closed
    private(set) var dockedEdge: DockedEdge = Defaults.dockedEdge
    private(set) var dockedYPosition: CGFloat = Defaults.yPosition
    var isWindowActive: Bool = false
    
    // MARK: - Computed Properties
    
    var isOpen: Bool { panelState == .open }
    var isClosed: Bool { panelState == .closed }
    
    // MARK: - Initialization
    
    init() {
        loadPersistedState()
        Log.info("WindowManager initialized: edge=\(dockedEdge.rawValue), y=\(dockedYPosition)", subsystem: .window)
    }
    
    // MARK: - Persistence
    
    private func loadPersistedState() {
        let defaults = UserDefaults.standard
        
        // Load docked edge
        if let edgeRaw = defaults.string(forKey: UserDefaultsKey.dockedEdge),
           let edge = DockedEdge(rawValue: edgeRaw) {
            dockedEdge = edge
        }
        
        // Load Y position
        let storedY = defaults.double(forKey: UserDefaultsKey.yPosition)
        if storedY > 0 {
            dockedYPosition = clamp(CGFloat(storedY), min: Defaults.minYPosition, max: Defaults.maxYPosition)
        }
    }
    
    private func persistState() {
        let defaults = UserDefaults.standard
        defaults.set(dockedEdge.rawValue, forKey: UserDefaultsKey.dockedEdge)
        defaults.set(Double(dockedYPosition), forKey: UserDefaultsKey.yPosition)
    }
    
    // MARK: - State Mutations
    
    func toggle() {
        let newState: PanelState = isOpen ? .closed : .open
        Log.debug("Panel toggling: \(panelState) → \(newState)", subsystem: .window)
        panelState = newState
        notifyStateChanged()
    }
    
    func open() {
        guard !isOpen else {
            Log.debug("Panel already open, ignoring open()", subsystem: .window)
            return
        }
        Log.debug("Panel opening", subsystem: .window)
        panelState = .open
        notifyStateChanged()
    }
    
    func close() {
        guard isOpen else {
            Log.debug("Panel already closed, ignoring close()", subsystem: .window)
            return
        }
        Log.debug("Panel closing", subsystem: .window)
        panelState = .closed
        notifyStateChanged()
    }
    
    func updateYPosition(_ y: CGFloat) {
        let clamped = clamp(y, min: Defaults.minYPosition, max: Defaults.maxYPosition)
        guard abs(clamped - dockedYPosition) > 0.5 else { return }  // Ignore tiny changes
        
        dockedYPosition = clamped
        persistState()
    }
    
    func setDockedEdge(_ edge: DockedEdge) {
        guard edge != dockedEdge else {
            Log.debug("Edge already \(edge.rawValue), ignoring setDockedEdge()", subsystem: .window)
            return
        }
        
        Log.info("Docked edge changing: \(dockedEdge.rawValue) → \(edge.rawValue)", subsystem: .window)
        dockedEdge = edge
        persistState()
        notifyStateChanged()
    }
    
    func toggleDockedEdge() {
        setDockedEdge(dockedEdge.opposite)
    }
    
    // MARK: - Notifications
    
    private func notifyStateChanged() {
        NotificationCenter.default.post(name: .panelStateChanged, object: nil)
    }
    
    // MARK: - Helpers
    
    private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
}
