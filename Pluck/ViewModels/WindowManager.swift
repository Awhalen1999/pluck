//
//  WindowManager.swift
//  Pluck
//
//  Central state manager for panel open/close behavior.
//

import Foundation

// MARK: - Panel State

enum PanelState: Equatable {
    case closed
    case open
}

// MARK: - Docked Edge

enum DockedEdge: String {
    case left
    case right
}

// MARK: - Window Manager

@Observable
final class WindowManager {
    
    // MARK: - Properties
    
    private(set) var panelState: PanelState = .closed
    var dockedEdge: DockedEdge = .right
    var dockedYPosition: CGFloat = 200
    var isWindowActive: Bool = false
    
    // MARK: - Computed
    
    var isOpen: Bool {
        panelState == .open
    }
    
    // MARK: - Actions
    
    func toggle() {
        panelState = isOpen ? .closed : .open
        notifyStateChanged()
    }
    
    func open() {
        guard !isOpen else { return }
        panelState = .open
        notifyStateChanged()
    }
    
    func close() {
        guard isOpen else { return }
        panelState = .closed
        notifyStateChanged()
    }
    
    func updateYPosition(_ y: CGFloat) {
        dockedYPosition = y
    }
    
    func setDockedEdge(_ edge: DockedEdge) {
        guard edge != dockedEdge else { return }
        dockedEdge = edge
        notifyStateChanged()
    }
    
    // MARK: - Notifications
    
    private func notifyStateChanged() {
        NotificationCenter.default.post(name: .panelStateChanged, object: nil)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let panelStateChanged = Notification.Name("panelStateChanged")
}
