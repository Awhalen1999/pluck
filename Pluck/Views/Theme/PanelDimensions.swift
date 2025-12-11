//
//  PanelDimensions.swift
//  Pluck
//
//  Single source of truth for all panel dimensions and frame calculations.
//

import Foundation
import AppKit

enum PanelDimensions {
    
    // MARK: - Panel Sizes
    
    static let closedSize = CGSize(width: 50, height: 100)
    static let openSize = CGSize(width: 220, height: 400)
    
    // MARK: - Corner Radius
    
    /// Radius for the outward-facing corners (away from screen edge)
    static let cornerRadius: CGFloat = 14
    
    // MARK: - Layout
    
    static let contentPadding: CGFloat = 12
    
    // MARK: - Size Helper
    
    static func size(for state: PanelState) -> CGSize {
        switch state {
        case .closed: return closedSize
        case .open: return openSize
        }
    }
    
    // MARK: - Frame Calculation
    
    @MainActor
    static func calculateFrame(
        for state: PanelState,
        dockedEdge: DockedEdge,
        yFromTop: CGFloat,
        screen: NSScreen
    ) -> NSRect {
        let screenRect = screen.visibleFrame
        let size = size(for: state)
        
        // X: Flush against the docked edge
        let x: CGFloat = switch dockedEdge {
        case .right: screenRect.maxX - size.width
        case .left: screenRect.minX
        }
        
        // Y: Position from top, clamped to screen bounds
        let y = screenRect.maxY - yFromTop - size.height
        let clampedY = y.clamped(to: screenRect.minY...screenRect.maxY - size.height)
        
        return NSRect(origin: CGPoint(x: x, y: clampedY), size: size)
    }
}


