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
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
            
            Text("New Folder")
                .font(.system(size: 13, weight: .medium))
            
            Spacer()
        }
        .foregroundStyle(isHovered ? Theme.textSecondary : Theme.textTertiary)
        .padding(.horizontal, Theme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .fill(isHovered ? Theme.cardBackground : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(isHovered ? Theme.borderHover : Theme.border)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { startAdding() }
    }
    
    // MARK: - Editing Card
    
    private var editingCard: some View {
        HStack(spacing: 0) {
            colorPicker
                .padding(.trailing, Theme.Spacing.sm)
            
            textField
            
            HStack(spacing: Theme.Spacing.sm) {
                cancelButton
                confirmButton
            }
            .padding(.leading, Theme.Spacing.sm)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .fill(Theme.cardBackgroundHover)
                .shadow(color: Theme.shadowLight, radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .stroke(Theme.borderHover, lineWidth: 1)
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
            .foregroundStyle(Theme.textPrimary)
            .focused($isTextFieldFocused)
            .frame(maxWidth: 130)
            .onSubmit { createFolder() }
            .onExitCommand { cancelAdding() }
    }
    
    private var cancelButton: some View {
        Button(action: cancelAdding) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
        }
        .buttonStyle(.plain)
    }
    
    private var confirmButton: some View {
        Button(action: createFolder) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
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
