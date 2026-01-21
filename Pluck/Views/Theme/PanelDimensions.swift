//
//  PanelDimensions.swift
//  Pluck
//
//  Single source of truth for all panel dimensions and frame calculations.
//  Robust calculations with validation and safety bounds.
//

import Foundation
import AppKit

// MARK: - Panel Dimensions

enum PanelDimensions {
    
    // MARK: - Panel Sizes
    
    static let closedSize = CGSize(width: 50, height: 125)
    static let openSize = CGSize(width: 225, height: 450)
    
    // MARK: - Constraints
    
    static let minWidth: CGFloat = 50
    static let minHeight: CGFloat = 100
    static let maxWidth: CGFloat = 400
    static let maxHeight: CGFloat = 800
    
    // MARK: - Corner Radius
    
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
        var size = size(for: state)
        
        // Validate and clamp size
        size.width = clamp(size.width, min: minWidth, max: Swift.min(maxWidth, screenRect.width))
        size.height = clamp(size.height, min: minHeight, max: Swift.min(maxHeight, screenRect.height))
        
        // Calculate X position based on docked edge
        let x: CGFloat
        switch dockedEdge {
        case .right:
            x = screenRect.maxX - size.width
        case .left:
            x = screenRect.minX
        }
        
        // Calculate Y position from top, clamped to screen bounds
        let maxYFromTop = screenRect.height - size.height
        let clampedYFromTop = clamp(yFromTop, min: 0, max: Swift.max(0, maxYFromTop))
        let y = screenRect.maxY - clampedYFromTop - size.height
        
        // Final validation
        let clampedY = clamp(y, min: screenRect.minY, max: screenRect.maxY - size.height)
        let clampedX = clamp(x, min: screenRect.minX, max: screenRect.maxX - size.width)
        
        let frame = NSRect(
            origin: CGPoint(x: clampedX, y: clampedY),
            size: size
        )
        
        Log.debug("Calculated frame: \(frame) for state: \(state), edge: \(dockedEdge.rawValue)", subsystem: .window)
        
        return frame
    }
    
    // MARK: - Clamping Helper
    
    private static func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
    
    // MARK: - Screen Utilities
    
    @MainActor
    static func currentScreen(for point: NSPoint? = nil) -> NSScreen {
        if let point = point {
            // Find screen containing the point
            for screen in NSScreen.screens {
                if screen.frame.contains(point) {
                    return screen
                }
            }
        }
        
        // Fall back to main screen
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }
    
    @MainActor
    static func isValidPosition(frame: NSRect, on screen: NSScreen) -> Bool {
        let screenRect = screen.visibleFrame
        return screenRect.intersects(frame)
    }
}
