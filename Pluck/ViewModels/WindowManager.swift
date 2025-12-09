//
//  WindowManager.swift
//  Pluck
//

import Foundation
import SwiftUI

// MARK: - Panel State

enum PanelState: Equatable {
    case collapsed
    case folderList
    case folderOpen(DesignFolder)
    case imageFocused(DesignImage)
    
    static func == (lhs: PanelState, rhs: PanelState) -> Bool {
        switch (lhs, rhs) {
        case (.collapsed, .collapsed),
             (.folderList, .folderList):
            return true
        case (.folderOpen(let a), .folderOpen(let b)):
            return a.id == b.id
        case (.imageFocused(let a), .imageFocused(let b)):
            return a.id == b.id
        default:
            return false
        }
    }
    
    var supportsExpansion: Bool {
        switch self {
        case .folderList, .folderOpen:
            return true
        case .collapsed, .imageFocused:
            return false
        }
    }
}

// MARK: - Docked Edge

enum DockedEdge: String {
    case left, right
}

// MARK: - Window Manager

@Observable
final class WindowManager {
    
    // MARK: - State
    
    private(set) var panelState: PanelState = .collapsed
    private(set) var activeFolder: DesignFolder?
    var isWindowActive: Bool = false
    
    var dockedEdge: DockedEdge = .right
    var dockedYPosition: CGFloat = 200
    
    // MARK: - Height Expansion
    
    var isHeightExpanded: Bool = UserDefaults.standard.bool(forKey: "panelHeightExpanded") {
        didSet {
            UserDefaults.standard.set(isHeightExpanded, forKey: "panelHeightExpanded")
            notifyHeightChanged()
        }
    }
    
    func toggleHeightExpansion() {
        isHeightExpanded.toggle()
    }
    
    // MARK: - Navigation
    
    func collapse() {
        panelState = .collapsed
        notifyStateChanged()
    }
    
    func showFolderList() {
        panelState = .folderList
        notifyStateChanged()
    }
    
    func openFolder(_ folder: DesignFolder) {
        activeFolder = folder
        panelState = .folderOpen(folder)
        notifyStateChanged()
    }
    
    func focusImage(_ image: DesignImage) {
        panelState = .imageFocused(image)
        notifyStateChanged()
    }
    
    func goBack() {
        switch panelState {
        case .imageFocused:
            panelState = activeFolder.map { .folderOpen($0) } ?? .folderList
        case .folderOpen:
            activeFolder = nil
            panelState = .folderList
        case .folderList:
            panelState = .collapsed
        case .collapsed:
            return
        }
        notifyStateChanged()
    }
    
    // MARK: - Docking
    
    func setDockedEdge(_ edge: DockedEdge) {
        guard edge != dockedEdge else { return }
        dockedEdge = edge
        notifyStateChanged()
    }
    
    func updateYPosition(_ yPosition: CGFloat) {
        dockedYPosition = yPosition
        notifyStateChanged()
    }
    
    // MARK: - Notifications
    
    private func notifyStateChanged() {
        NotificationCenter.default.post(name: .panelStateChanged, object: nil)
    }
    
    private func notifyHeightChanged() {
        NotificationCenter.default.post(name: .panelHeightChanged, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let panelStateChanged = Notification.Name("panelStateChanged")
    static let panelHeightChanged = Notification.Name("panelHeightChanged")
}
