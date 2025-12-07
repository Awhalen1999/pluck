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
    @State private var selectedColorIndex = 0
    @State private var draggingFolder: DesignFolder?
    @State private var draggingIndex: Int?
    @State private var targetIndex: Int?
    @FocusState private var isTextFieldFocused: Bool
    
    private let cardHeight: CGFloat = 68
    private let cardSpacing: CGFloat = 8
    
    private let colorOptions = [
        "#8B5CF6", // Purple
        "#3B82F6", // Blue
        "#10B981", // Green
        "#F59E0B", // Amber
        "#EF4444", // Red
        "#EC4899", // Pink
        "#6366F1", // Indigo
        "#14B8A6", // Teal
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollView {
                LazyVStack(spacing: cardSpacing) {
                    ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                        BoxCardView(
                            folder: folder,
                            onTap: { windowManager.openFolder(folder) },
                            onDragStarted: {
                                draggingFolder = folder
                                draggingIndex = index
                                targetIndex = index
                            },
                            onDragChanged: { translation in
                                updateTargetIndex(from: index, translation: translation)
                            },
                            onDragEnded: {
                                commitReorder()
                            }
                        )
                        .offset(y: offsetForIndex(index))
                        .zIndex(draggingIndex == index ? 100 : 0)
                    }
                    
                    newFolderCard
                }
                .padding(12)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: targetIndex)
            }
        }
    }
    
    // MARK: - Calculate offset for shifting cards
    
    private func offsetForIndex(_ index: Int) -> CGFloat {
        guard let dragging = draggingIndex, let target = targetIndex else { return 0 }
        
        // Don't offset the dragging card itself
        if index == dragging { return 0 }
        
        let itemHeight = cardHeight + cardSpacing
        
        if dragging < target {
            // Dragging down: items between dragging and target shift UP
            if index > dragging && index <= target {
                return -itemHeight
            }
        } else if dragging > target {
            // Dragging up: items between target and dragging shift DOWN
            if index >= target && index < dragging {
                return itemHeight
            }
        }
        
        return 0
    }
    
    // MARK: - Update target index based on drag translation
    
    private func updateTargetIndex(from originalIndex: Int, translation: CGSize) {
        let itemHeight = cardHeight + cardSpacing
        let dragOffset = Int(round(translation.height / itemHeight))
        var newIndex = originalIndex + dragOffset
        
        // Clamp to valid range
        newIndex = max(0, min(newIndex, folders.count - 1))
        
        if newIndex != targetIndex {
            targetIndex = newIndex
        }
    }
    
    // MARK: - Commit the reorder
    
    private func commitReorder() {
        guard let fromIndex = draggingIndex, let toIndex = targetIndex, fromIndex != toIndex else {
            draggingFolder = nil
            draggingIndex = nil
            targetIndex = nil
            return
        }
        
        // Reorder the folders
        var sorted = folders.sorted { $0.sortOrder < $1.sortOrder }
        let moved = sorted.remove(at: fromIndex)
        sorted.insert(moved, at: toIndex)
        
        // Update sort orders
        for (index, folder) in sorted.enumerated() {
            folder.sortOrder = index
        }
        
        draggingFolder = nil
        draggingIndex = nil
        targetIndex = nil
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("Folders")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
            
            Button(action: { windowManager.collapse() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - New Folder Card
    
    private var newFolderCard: some View {
        Group {
            if isAddingFolder {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: colorOptions[selectedColorIndex]) ?? .purple)
                        .frame(width: 10, height: 10)
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.15)) {
                                selectedColorIndex = (selectedColorIndex + 1) % colorOptions.count
                            }
                        }
                    
                    TextField("Folder name", text: $newFolderName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .focused($isTextFieldFocused)
                        .onSubmit { createFolder() }
                        .onExitCommand { cancelAddFolder() }
                    
                    Spacer()
                    
                    Button(action: { createFolder() }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
                .onAppear {
                    isTextFieldFocused = true
                }
            } else {
                Button(action: { withAnimation(.easeOut(duration: 0.15)) { isAddingFolder = true } }) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text("New Folder")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Actions
    
    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            cancelAddFolder()
            return
        }
        
        let folder = DesignFolder(name: name, sortOrder: folders.count)
        folder.colorHex = colorOptions[selectedColorIndex]
        modelContext.insert(folder)
        
        withAnimation(.easeOut(duration: 0.15)) {
            newFolderName = ""
            selectedColorIndex = 0
            isAddingFolder = false
        }
    }
    
    private func cancelAddFolder() {
        withAnimation(.easeOut(duration: 0.15)) {
            newFolderName = ""
            selectedColorIndex = 0
            isAddingFolder = false
        }
    }
}

// MARK: - Box Card View

struct BoxCardView: View {
    let folder: DesignFolder
    let onTap: () -> Void
    let onDragStarted: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var isHovered = false
    @State private var isDropTargeted = false
    @State private var thumbnails: [NSImage] = []
    
    // Drag state
    @State private var holdTimer: Timer?
    @State private var canDrag = false
    @State private var dragOffset: CGSize = .zero
    @State private var wiggleAngle: Double = 0
    
    private let holdDuration: TimeInterval = 0.5
    
    private var folderColor: Color {
        Color(hex: folder.colorHex) ?? .purple
    }
    
    var body: some View {
        cardContent
            .offset(y: canDrag ? dragOffset.height : 0)
            .scaleEffect(canDrag ? 1.03 : (isDropTargeted ? 1.02 : 1.0))
            .rotationEffect(.degrees(wiggleAngle))
            .shadow(color: .black.opacity(canDrag ? 0.4 : 0), radius: canDrag ? 12 : 0, y: canDrag ? 6 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: canDrag)
            .animation(.easeOut(duration: 0.15), value: isDropTargeted)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if holdTimer == nil && !canDrag {
                            holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { _ in
                                DispatchQueue.main.async {
                                    canDrag = true
                                    onDragStarted()
                                    startWiggle()
                                }
                            }
                        }
                        
                        if canDrag {
                            dragOffset = value.translation
                            onDragChanged(value.translation)
                        }
                    }
                    .onEnded { _ in
                        holdTimer?.invalidate()
                        holdTimer = nil
                        
                        if !canDrag {
                            onTap()
                        } else {
                            stopWiggle()
                            onDragEnded()
                        }
                        
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            dragOffset = .zero
                            canDrag = false
                        }
                    }
            )
            .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
                handleImageDrop(providers)
            }
    }
    
    private var cardContent: some View {
        HStack(spacing: 12) {
            // Color accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(folderColor)
                .frame(width: 4)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Title row
                HStack {
                    Text(folder.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(folder.imageCount) item\(folder.imageCount == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                // Thumbnail row or empty state
                if folder.images.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.2))
                        
                        Text("Drop images here")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                } else {
                    HStack(spacing: -8) {
                        ForEach(Array(thumbnails.prefix(4).enumerated()), id: \.offset) { index, image in
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.black.opacity(0.5), lineWidth: 1)
                                )
                                .zIndex(Double(4 - index))
                        }
                        
                        if folder.imageCount > 4 {
                            Text("+\(folder.imageCount - 4)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.leading, 12)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(canDrag ? 0.12 : (isDropTargeted ? 0.1 : (isHovered ? 0.08 : 0.05))))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isDropTargeted ? folderColor.opacity(0.6) : .white.opacity(isHovered ? 0.12 : 0.06),
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            loadThumbnails()
        }
        .onChange(of: folder.images.count) { _, _ in
            loadThumbnails()
        }
    }
    
    // MARK: - Wiggle
    
    private func startWiggle() {
        withAnimation(
            .easeInOut(duration: 0.1)
            .repeatForever(autoreverses: true)
        ) {
            wiggleAngle = 1.5
        }
    }
    
    private func stopWiggle() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            wiggleAngle = 0
        }
    }
    
    // MARK: - Thumbnails
    
    private func loadThumbnails() {
        let sortedImages = folder.images.sorted { $0.sortOrder < $1.sortOrder }
        let imagesToLoad = Array(sortedImages.prefix(4))
        
        DispatchQueue.global(qos: .userInitiated).async {
            var loaded: [NSImage] = []
            for image in imagesToLoad {
                if let thumb = FileManagerHelper.loadThumbnail(filename: image.filename) {
                    loaded.append(thumb)
                }
            }
            DispatchQueue.main.async {
                self.thumbnails = loaded
            }
        }
    }
    
    // MARK: - Image Drop
    
    private func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                    guard let data = data else { return }
                    
                    DispatchQueue.main.async {
                        if let filename = FileManagerHelper.saveImage(data, originalName: "Dropped Image") {
                            let newImage = DesignImage(
                                filename: filename,
                                originalName: "Dropped Image",
                                sortOrder: folder.images.count,
                                folder: folder
                            )
                            modelContext.insert(newImage)
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}

// MARK: - Color Extension

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
        .frame(width: 220, height: 350)
        .background(Color.black.opacity(0.8))
}
