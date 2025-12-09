//
//  PanelDimensions.swift
//  Pluck
//

import Foundation

enum PanelDimensions {
    
    // MARK: - Panel Sizes
    
    static let collapsedSize = CGSize(width: 50, height: 50)
    static let folderListSize = CGSize(width: 220, height: 350)
    static let folderDetailSize = CGSize(width: 220, height: 350)
    static let imageDetailSize = CGSize(width: 340, height: 400)
    
    // MARK: - Layout
    
    static let edgeMargin: CGFloat = 10
    static let contentPadding: CGFloat = 12
    
    // MARK: - Header
    
    static let headerHeight: CGFloat = 40
    
    // MARK: - Corner Radii
    
    static let collapsedCornerRadius: CGFloat = 12
    static let expandedCornerRadius: CGFloat = 14
    
    // MARK: - Grid
    
    static let thumbnailSize: CGFloat = 72
    static let thumbnailSpacing: CGFloat = 6
    static let thumbnailCornerRadius: CGFloat = 6
    
    // MARK: - Folder Cards
    
    static let folderCardHeight: CGFloat = 68
    static let folderCardSpacing: CGFloat = 8
    static let folderCardCornerRadius: CGFloat = 10
    
    // MARK: - Dynamic Height
    
    static func listHeight(expanded: Bool, screenHeight: CGFloat) -> CGFloat {
        if expanded {
            return screenHeight - (edgeMargin * 2)
        }
        return folderListSize.height
    }
    
    // MARK: - NSSize Conversions (for AppKit)
    
    static var collapsedNSSize: NSSize {
        NSSize(width: collapsedSize.width, height: collapsedSize.height)
    }
    
    static var folderListNSSize: NSSize {
        NSSize(width: folderListSize.width, height: folderListSize.height)
    }
    
    static var folderDetailNSSize: NSSize {
        NSSize(width: folderDetailSize.width, height: folderDetailSize.height)
    }
    
    static var imageDetailNSSize: NSSize {
        NSSize(width: imageDetailSize.width, height: imageDetailSize.height)
    }
}
