import SwiftUI

/// Every shot, pinned first and then by day. Clicking a shot copies it and the
/// Shelf stays open. It has the keyboard while it's open; see `ShelfKey`.
struct ShelfView: View {
    let controller: NotchController
    let notchWidth: CGFloat

    var body: some View {
        let content = controller.content
        let sections = NotchLayout.shelfSections(content)
        // Only a Shelf with more than fits scrolls, shows a scroller, or bounces.
        let fits = NotchLayout.shelfHeight(sections) <= Theme.Notch.shelfMaxHeight - Theme.Notch.headerHeight
        VStack(spacing: 0) {
            NotchHeader(notchWidth: notchWidth) {
                if let shot = controller.focusedShot.flatMap({ id in content.shots.first { $0.id == id } }) {
                    Text(shot.detail)
                } else {
                    Text(content.shots.count == 1 ? "1 shot" : "\(content.shots.count) shots")
                }
            } trailing: {
                if let feedback = controller.feedback {
                    FeedbackLabel(feedback: feedback, controller: controller)
                } else if !controller.selection.isEmpty {
                    SelectionLabel(count: controller.selection.count, controller: controller)
                }
            }
            if sections.isEmpty {
                NoShotsYet().frame(height: Theme.Notch.controlHeight)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(sections) { section in
                                ForEach(section.rows) { row in
                                    // A section's title is part of its first row, so a
                                    // row scrolled into view brings its title along.
                                    VStack(alignment: .leading, spacing: 0) {
                                        if row.id == section.rows.first?.id { SectionHeader(section: section) }
                                        HStack(spacing: Theme.Space.s) {
                                            ForEach(row.tiles) { tile in
                                                ShotTile(shot: tile.shot, size: tile.size, controller: controller)
                                            }
                                        }
                                        .padding(.bottom, Theme.Space.s)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Space.xl)
                    }
                    // A margin, not padding, so a row scrolled to stays clear of the edge.
                    .contentMargins(.bottom, NotchLayout.shelfBottomPadding, for: .scrollContent)
                    .scrollIndicators(fits ? .never : .automatic)
                    .scrollBounceBehavior(.basedOnSize)
                    .onChange(of: controller.focusedShot) { _, id in
                        // A shot reached with the arrow keys stays in view. Its row is
                        // what scrolls: a lazy stack only knows its rows.
                        guard controller.focusFollowsKeyboard, let id,
                              let row = sections.lazy.flatMap(\.rows).first(where: { $0.tiles.contains { $0.id == id } })
                        else { return }
                        proxy.scrollTo(row.id)
                    }
                }
            }
        }
    }
}

/// "3 selected · Clear", in the feedback slot while nothing more recent is there.
private struct SelectionLabel: View {
    let count: Int
    let controller: NotchController

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Text("\(count) selected")
                .foregroundStyle(.primary)
                .allowsHitTesting(false)
            Button("Clear") { controller.clearSelection() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Palette.accent)
        }
        .font(Theme.Typography.label)
        .transition(.blurReplace)
    }
}

private struct SectionHeader: View {
    let section: NotchLayout.ShelfSection

    var body: some View {
        HStack {
            Text(section.title)
                .font(Theme.Typography.title)
                .foregroundStyle(.primary)
            Spacer()
            if let note = section.note {
                Text(note)
                    .font(Theme.Typography.detail)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: Theme.Notch.sectionHeaderHeight)
        .allowsHitTesting(false)
        .accessibilityAddTraits(.isHeader)
    }
}
