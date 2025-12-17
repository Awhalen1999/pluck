//
//  ImageDropWatcher.swift
//  Pluck
//

import SwiftUI
import UniformTypeIdentifiers

/// A drop delegate that only shows targeting UI for valid image types
struct ImageDropWatcher: DropDelegate {
    
    @Binding var isTargeted: Bool
    let onDrop: ([NSItemProvider]) -> Bool
    var onSuccess: (() -> Void)? = nil
    
    // MARK: - Supported Types
    
    private static let supportedExtensions = FileManagerHelper.supportedImageExtensions
    
    private static let imageUTTypes: Set<UTType> = [
        .png, .jpeg, .gif, .tiff, .bmp, .heic, .svg, .webP,
        .image // Generic image type
    ]
    
    // MARK: - DropDelegate
    
    func validateDrop(info: DropInfo) -> Bool {
        // Check if any provider has a valid image type
        return hasValidImageContent(info: info)
    }
    
    func dropEntered(info: DropInfo) {
        // Only show targeting if content is valid
        if hasValidImageContent(info: info) {
            withAnimation(.easeOut(duration: 0.15)) {
                isTargeted = true
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        if hasValidImageContent(info: info) {
            return DropProposal(operation: .copy)
        }
        return DropProposal(operation: .forbidden)
    }
    
    func dropExited(info: DropInfo) {
        withAnimation(.easeOut(duration: 0.15)) {
            isTargeted = false
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        
        let providers = info.itemProviders(for: [.item])
        let validProviders = providers.filter { isValidProvider($0) }
        
        guard !validProviders.isEmpty else { return false }
        
        let result = onDrop(validProviders)
        if result {
            onSuccess?()
        }
        return result
    }
    
    // MARK: - Validation
    
    private func hasValidImageContent(info: DropInfo) -> Bool {
        // Get all providers
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
        
        // Check registered type identifiers for image conformance
        let registeredTypes = provider.registeredTypeIdentifiers
        
        for identifier in registeredTypes {
            // Check if it's a known image identifier
            if isKnownImageIdentifier(identifier) {
                return true
            }
            
            // Check UTType conformance
            if let utType = UTType(identifier), utType.conforms(to: .image) {
                return true
            }
        }
        
        // For file URLs, we need to check the suggested name for extension
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            // Check suggested name if available
            if let suggestedName = provider.suggestedName {
                let ext = (suggestedName as NSString).pathExtension.lowercased()
                if Self.supportedExtensions.contains(ext) {
                    return true
                }
            }
            
            // If it's a file URL but we also have image type, accept it
            for type in Self.imageUTTypes {
                if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func isKnownImageIdentifier(_ identifier: String) -> Bool {
        let knownIdentifiers: Set<String> = [
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
        
        return knownIdentifiers.contains(identifier)
    }
}
