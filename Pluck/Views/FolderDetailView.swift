//
//  FolderDetailView.swift
//  Pluck
//

import SwiftUI

struct FolderDetailView: View {
    let folder: DesignFolder
    let onBack: () -> Void
    let onSelectImage: (DesignImage) -> Void
    
    @Environment(WindowManager.self) private var windowManager
    
    @State private var isBackHovered = false
    @State private var isCloseHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Spacer()
            
            Text("Folder: \(folder.name)")
                .foregroundStyle(.white.opacity(0.5))
            
            Spacer()
        }
    }
    
    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isBackHovered ? .white : .white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isBackHovered ? .white.opacity(0.1) : .clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isBackHovered = $0 }
            
            Spacer()
            
            Button(action: { windowManager.close() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isCloseHovered ? .white : .white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isCloseHovered ? .white.opacity(0.1) : .clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isCloseHovered = $0 }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
    }
}
