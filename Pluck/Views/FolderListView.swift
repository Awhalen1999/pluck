//
//  FolderListView.swift
//  Pluck
//

import SwiftUI
import SwiftData

struct FolderListView: View {
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DesignFolder.sortOrder) private var folders: [DesignFolder]
    
    @State private var isAddingFolder = false
    @State private var newFolderName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Folders")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(action: { windowManager.collapse() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Folder list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(folders) { folder in
                        FolderRowView(folder: folder)
                            .onTapGesture {
                                windowManager.openFolder(folder)
                            }
                    }
                    
                    // Add folder button or input
                    if isAddingFolder {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.purple.opacity(0.6))
                                .frame(width: 8, height: 8)
                            
                            TextField("Folder name", text: $newFolderName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundStyle(.white)
                                .onSubmit {
                                    createFolder()
                                }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Add folder button
            Button(action: {
                withAnimation {
                    isAddingFolder = true
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("New Folder")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func createFolder() {
        guard !newFolderName.isEmpty else {
            isAddingFolder = false
            return
        }
        
        let folder = DesignFolder(name: newFolderName, sortOrder: folders.count)
        modelContext.insert(folder)
        
        newFolderName = ""
        isAddingFolder = false
    }
}

struct FolderRowView: View {
    let folder: DesignFolder
    @Environment(WindowManager.self) private var windowManager
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: folder.colorHex) ?? .purple)
                .frame(width: 8, height: 8)
            
            Text(folder.name)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
            
            Text("\(folder.imageCount)")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 12)
    }
}

// Color hex extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

#Preview {
    FolderListView()
        .environment(WindowManager())
        .modelContainer(for: [DesignFolder.self, DesignImage.self])
        .frame(width: 280, height: 350)
}
