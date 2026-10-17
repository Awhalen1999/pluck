import SwiftUI

/// Every shot, pinned first and then by day. Clicking a shot copies it and the
/// Shelf stays open; it closes on a click anywhere else.
struct ShelfView: View {
    let controller: NotchController
    let notchWidth: CGFloat

    var body: some View {
        let content = controller.content
        let sections = NotchLayout.shelfSections(content)
        VStack(spacing: 0) {
            NotchHeader(notchWidth: notchWidth) {
                if let shot = controller.hoveredShot.flatMap({ id in content.shots.first { $0.id == id } }) {
                    Text(shot.detail)
                } else {
                    Text(content.shots.count == 1 ? "1 shot" : "\(content.shots.count) shots")
                }
            } trailing: {
                if let feedback = controller.feedback { FeedbackLabel(feedback: feedback, controller: controller) }
            }
            if sections.isEmpty {
                NoShotsYet().frame(height: Theme.Notch.controlHeight)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(sections) { section in
                            SectionHeader(section: section)
                            ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                                HStack(spacing: Theme.Space.s) {
                                    ForEach(row) { tile in
                                        ShotTile(shot: tile.shot, size: tile.size, controller: controller)
                                    }
                                }
                                .padding(.bottom, Theme.Space.s)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Space.xl)
                    .padding(.bottom, NotchLayout.shelfBottomPadding)
                }
            }
        }
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
        .accessibilityAddTraits(.isHeader)
    }
}
