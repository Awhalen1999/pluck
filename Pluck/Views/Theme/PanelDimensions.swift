//
//  PanelDimensions.swift
//  Pluck
//

import Foundation
import AppKit

// MARK: - Panel Dimensions

/// Unified panel sizing system - single source of truth for all panel dimensions
enum PanelDimensions {
    
    // MARK: - Base Sizes
    
    static let collapsedSize = CGSize(width: 50, height: 50)
    static let folderListWidth: CGFloat = 220
    static let imageDetailWidth: CGFloat = 340
    static let imageDetailContentHeight: CGFloat = 400
    
    // MARK: - Layout Constants
    
    static let edgeMargin: CGFloat = 0
    static let contentPadding: CGFloat = 12
    static let headerHeight: CGFloat = 40
    
    // MARK: - Corner Radii
    
    static let collapsedCornerRadius: CGFloat = 12
    static let expandedCornerRadius: CGFloat = 14
    
    // MARK: - Grid & Cards
    
    static let thumbnailSize: CGFloat = 72
    static let thumbnailSpacing: CGFloat = 6
    static let thumbnailCornerRadius: CGFloat = 6
    
    static let folderCardHeight: CGFloat = 68
    static let folderCardSpacing: CGFloat = 8
    static let folderCardCornerRadius: CGFloat = 10
    
    // MARK: - Dynamic Sizing
    
    /// Returns the appropriate panel size for a given state
    static func size(for state: PanelState, screenHeight: CGFloat) -> CGSize {
        switch state {
        case .collapsed:
            return collapsedSize
            
        case .folderList, .folderOpen:
            let height = collapsedSize.height + listContentHeight(screenHeight: screenHeight)
            return CGSize(width: folderListWidth, height: height)
            
        case .imageFocused:
            let height = collapsedSize.height + imageDetailContentHeight
            return CGSize(width: imageDetailWidth, height: height)
        }
    }
    
    /// Returns 55% of screen height for list content area
    private static func listContentHeight(screenHeight: CGFloat) -> CGFloat {
        return screenHeight * 0.55
    }
    
    /// Helper for SwiftUI views to get the expanded content height
    static func listHeight(screenHeight: CGFloat) -> CGFloat {
        return listContentHeight(screenHeight: screenHeight)
    }
}

// MARK: - Frame Calculation

extension PanelDimensions {
    
    /// Calculates the panel frame for a given state and screen
    @MainActor
    static func calculateFrame(
        for state: PanelState,
        dockedEdge: DockedEdge,
        yFromTop: CGFloat,
        screen: NSScreen
    ) -> NSRect {
        let screenRect = screen.visibleFrame
        let size = self.size(for: state, screenHeight: screenRect.height)
        let origin = calculateOrigin(
            size: size,
            dockedEdge: dockedEdge,
            yFromTop: yFromTop,
            in: screenRect
        )
        return NSRect(origin: origin, size: size)
    }
    
    /// Calculates the panel origin point
    private static func calculateOrigin(
        size: CGSize,
        dockedEdge: DockedEdge,
        yFromTop: CGFloat,
        in screenRect: NSRect
    ) -> NSPoint {
        // X position based on docked edge
        let x: CGFloat
        if dockedEdge == .right {
            x = screenRect.maxX - size.width - edgeMargin
        } else {
            x = screenRect.minX + edgeMargin
        }
        
        // Y position from top
        let y = screenRect.maxY - yFromTop - size.height
        let clampedY = y.clamped(
            to: screenRect.minY + edgeMargin...screenRect.maxY - size.height - edgeMargin
        )
        
        return NSPoint(x: x, y: clampedY)
    }
}
