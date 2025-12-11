//
//  NewFolderCard.swift
//  Pluck
//

import SwiftUI

struct NewFolderCard: View {
    @Binding var isAdding: Bool
    let onCreate: (String, String) -> Void
    
    @State private var folderName = ""
    @State private var selectedColorIndex = 0
    @State private var isHovered = false
    @FocusState private var isTextFieldFocused: Bool
    
    // MARK: - Constants
    
    private let cardHeight: CGFloat = 44
    private let cardCornerRadius: CGFloat = 10
    private let contentPadding: CGFloat = 12
    
    private var selectedColor: String {
        FolderColors.all[selectedColorIndex]
    }
    
    var body: some View {
        Group {
            if isAdding {
                editingCard
            } else {
                addButton
            }
        }
        .frame(height: cardHeight)
    }
    
    // MARK: - Add Button
    
    private var addButton: some View {
        Button(action: startAdding) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                
                Text("New Folder")
                    .font(.system(size: 13, weight: .medium))
                
                Spacer()
            }
            .foregroundStyle(isHovered ? .white.opacity(0.7) : .white.opacity(0.4))
            .padding(.horizontal, contentPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .fill(isHovered ? .white.opacity(0.05) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(isHovered ? .white.opacity(0.2) : .white.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    // MARK: - Editing Card
    
    private var editingCard: some View {
        HStack(spacing: 0) {
            colorPicker
                .padding(.trailing, 10)
            
            textField
            
            HStack(spacing: 8) {
                cancelButton
                confirmButton
            }
            .padding(.leading, 10)
        }
        .padding(.horizontal, contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    // MARK: - Components
    
    private var colorPicker: some View {
        Circle()
            .fill(Color(hex: selectedColor) ?? .purple)
            .frame(width: 10, height: 10)
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.15)) {
                    selectedColorIndex = (selectedColorIndex + 1) % FolderColors.all.count
                }
            }
    }
    
    private var textField: some View {
        TextField("Folder name", text: $folderName)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .focused($isTextFieldFocused)
            .frame(maxWidth: 130)
            .onSubmit { createFolder() }
            .onExitCommand { cancelAdding() }
    }
    
    private var cancelButton: some View {
        Button(action: cancelAdding) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .buttonStyle(.plain)
    }
    
    private var confirmButton: some View {
        Button(action: createFolder) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func startAdding() {
        withAnimation(.easeOut(duration: 0.15)) {
            isAdding = true
        }
    }
    
    private func createFolder() {
        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            cancelAdding()
            return
        }
        
        onCreate(name, selectedColor)
        resetState()
    }
    
    private func cancelAdding() {
        withAnimation(.easeOut(duration: 0.15)) {
            resetState()
        }
    }
    
    private func resetState() {
        isAdding = false
        folderName = ""
        selectedColorIndex = 0
    }
}

// MARK: - Folder Colors

enum FolderColors {
    static let all = [
        "#FF6B6B", // Red
        "#FF8E53", // Orange
        "#FFD93D", // Yellow
        "#6BCB77", // Green
        "#4D96FF", // Blue
        "#9B72FF", // Purple
        "#FF6B9D", // Pink
    ]
}
