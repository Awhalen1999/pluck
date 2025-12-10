//
//  ImageDetailBody.swift
//  Pluck
//
//  Created by Alex Whalen on 2025-12-10.
//

import SwiftUI
import SwiftData

/// Implementation of image detail view with full image display and controls
struct ImageDetailBody: View {
    let image: DesignImage
    
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var fullImage: NSImage?
    @State private var isHoveringDelete = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            Divider()
                .background(Theme.border)
            
            imageContent
            
            if let sourceURL = image.sourceURL, !sourceURL.isEmpty {
                sourceURLBar(sourceURL)
            }
        }
        .onAppear {
            loadFullImage()
        }
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack {
            Button(action: { windowManager.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Text(image.originalName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .padding(.leading, 4)
            
            Spacer()
            
            Button(action: deleteImage) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(isHoveringDelete ? .red : Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .onHover { isHoveringDelete = $0 }
            .padding(.trailing, 4)
            
            Button(action: { windowManager.collapse() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
    
    // MARK: - Image Content
    
    @ViewBuilder
    private var imageContent: some View {
        if let fullImage = fullImage {
            Image(nsImage: fullImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .onDrag {
                    NSItemProvider(object: fullImage)
                }
        } else {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Spacer()
        }
    }
    
    // MARK: - Source URL Bar
    
    private func sourceURLBar(_ urlString: String) -> some View {
        VStack(spacing: 0) {
            Divider()
                .background(Theme.border)
            
            HStack {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                
                Text(urlString)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { copyToClipboard(urlString) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - Actions
    
    private func loadFullImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = FileManagerHelper.loadImage(filename: image.filename)
            DispatchQueue.main.async {
                self.fullImage = loaded
            }
        }
    }
    
    private func deleteImage() {
        FileManagerHelper.deleteImage(filename: image.filename)
        modelContext.delete(image)
        windowManager.goBack()
    }
    
    private func copyToClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
