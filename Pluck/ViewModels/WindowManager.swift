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
        case (.collapsed, .collapsed): return true
        case (.folderList, .folderList): return true
        case (.folderOpen(let a), .folderOpen(let b)): return a.id == b.id
        case (.imageFocused(let a), .imageFocused(let b)): return a.id == b.id
        default: return false
        }
    }
}

// MARK: - Docked Edge

enum DockedEdge: String {
    case left
    case right
}

// MARK: - Window Manager

@Observable
class WindowManager {
    var panelState: PanelState = .collapsed
    var activeFolder: DesignFolder?
    
    // Edge docking state
    var dockedEdge: DockedEdge = .right
    var dockedYPosition: CGFloat = 200  // Distance from top of screen
    
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
            if let folder = activeFolder {
                panelState = .folderOpen(folder)
            } else {
                panelState = .folderList
            }
        case .folderOpen:
            activeFolder = nil
            panelState = .folderList
        case .folderList:
            panelState = .collapsed
        case .collapsed:
            break
        }
        notifyStateChanged()
    }
    
    func setDockedEdge(_ edge: DockedEdge) {
        dockedEdge = edge
        notifyStateChanged()
    }
    
    func updateYPosition(_ yPosition: CGFloat) {
        dockedYPosition = yPosition
        notifyStateChanged()
    }
    
    private func notifyStateChanged() {
        NotificationCenter.default.post(name: .panelStateChanged, object: nil)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let panelStateChanged = Notification.Name("panelStateChanged")
}
