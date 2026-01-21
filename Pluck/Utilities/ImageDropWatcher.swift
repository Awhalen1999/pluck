//
//  ImageDropWatcher.swift
//  Pluck
//
//  A drop delegate that validates and handles image drops.
//  Comprehensive format detection with proper error handling.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Image Drop Watcher

struct ImageDropWatcher: DropDelegate {
    
    // MARK: - Properties
    
    @Binding var isTargeted: Bool
    let onDrop: ([NSItemProvider]) -> Bool
    var onSuccess: (() -> Void)? = nil
    
    // MARK: - Supported Types
    
    private static let supportedExtensions = FileManagerHelper.supportedImageExtensions
    
    private static let imageUTTypes: Set<UTType> = [
        .png,
        .jpeg,
        .gif,
        .tiff,
        .bmp,
        .heic,
        .svg,
        .webP,
        .image  // Generic image type
    ]
    
    private static let knownImageIdentifiers: Set<String> = [
        "public.png",
        "public.jpeg",
        "public.jpg",
        "public.gif",
        "public.tiff",
        "public.svg-image",
        "public.heic",
        "public.heif",
        "public.webp",
        "public.bmp",
        "public.image",
        "com.compuserve.gif",
        "org.webmproject.webp",
        "com.microsoft.bmp",
        "com.apple.icns"
    ]
    
    // MARK: - Animation Config
    
    private static let animationDuration: TimeInterval = 0.15
    
    // MARK: - DropDelegate Implementation
    
    func validateDrop(info: DropInfo) -> Bool {
        let isValid = hasValidImageContent(info: info)
        Log.debug("Drop validation: \(isValid)", subsystem: .drop)
        return isValid
    }
    
    func dropEntered(info: DropInfo) {
        guard hasValidImageContent(info: info) else {
            Log.debug("Drop entered but no valid image content", subsystem: .drop)
            return
        }
        
        withAnimation(.easeOut(duration: Self.animationDuration)) {
            isTargeted = true
        }
        Log.debug("Drop targeting activated", subsystem: .drop)
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        if hasValidImageContent(info: info) {
            return DropProposal(operation: .copy)
        }
        return DropProposal(operation: .forbidden)
    }
    
    func dropExited(info: DropInfo) {
        withAnimation(.easeOut(duration: Self.animationDuration)) {
            isTargeted = false
        }
        Log.debug("Drop targeting deactivated", subsystem: .drop)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        // Reset targeting state immediately
        isTargeted = false
        
        let providers = info.itemProviders(for: [.item])
        let validProviders = providers.filter { isValidProvider($0) }
        
        guard !validProviders.isEmpty else {
            Log.warning("Drop performed but no valid providers found", subsystem: .drop)
            return false
        }
        
        Log.info("Processing drop with \(validProviders.count) valid provider(s)", subsystem: .drop)
        
        let result = onDrop(validProviders)
        
        if result {
            Log.info("Drop handled successfully", subsystem: .drop)
            onSuccess?()
        } else {
            Log.warning("Drop handler returned false", subsystem: .drop)
        }
        
        return result
    }
    
    // MARK: - Validation
    
    private func hasValidImageContent(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.item])
        return providers.contains { isValidProvider($0) }
    }
    
    private func isValidProvider(_ provider: NSItemProvider) -> Bool {
        // Check for direct image types
        for type in Self.imageUTTypes {
            if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                return true
            }
        }
        
        // Check registered type identifiers
        let registeredTypes = provider.registeredTypeIdentifiers
        
        for identifier in registeredTypes {
            // Check against known image identifiers
            if Self.knownImageIdentifiers.contains(identifier) {
                return true
            }
            
            // Check UTType conformance
            if let utType = UTType(identifier), utType.conforms(to: .image) {
                return true
            }
        }
        
        // For file URLs, check the suggested name extension
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let suggestedName = provider.suggestedName {
                let ext = (suggestedName as NSString).pathExtension.lowercased()
                if Self.supportedExtensions.contains(ext) {
                    return true
                }
            }
            
            // File URL with any image type indicator
            for type in Self.imageUTTypes {
                if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                    return true
                }
            }
        }
        
        return false
    }
}
