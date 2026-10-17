import SwiftUI

/// The notch's shape: flat against the top of the screen, rounded at the bottom.
nonisolated struct NotchShape: Shape {
    var radius: CGFloat

    /// The coordinate space of the notch's current, animating bounds.
    static let space = "notch"

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous)
            .path(in: rect)
    }
}

extension View {
    /// Puts the view on the notch surface: Liquid Glass, kept pure black level
    /// with the hardware notch so the two read as one piece. Content is clipped
    /// to the shape, so nothing shows outside it while it grows or shrinks.
    func notchSurface(radius: CGFloat) -> some View {
        let shape = NotchShape(radius: radius)
        return coordinateSpace(.named(NotchShape.space))
            .clipShape(shape)
            .background {
                Color.clear
                    .glassEffect(.regular.tint(Theme.Notch.glassTint), in: shape)
                    .overlay(alignment: .top) {
                        LinearGradient(stops: [
                            .init(color: Theme.Notch.fill, location: 0),
                            .init(color: Theme.Notch.fill, location: Theme.Notch.headerHeight / (Theme.Notch.headerHeight + Theme.Notch.glassFade)),
                            .init(color: .clear, location: 1),
                        ], startPoint: .top, endPoint: .bottom)
                        .frame(height: Theme.Notch.headerHeight + Theme.Notch.glassFade)
                    }
                    .clipShape(shape)
            }
    }

    /// Makes content exactly as visible as it is inside the notch, so it fades
    /// in as the growing shape reaches it. Pure geometry, read every frame: it
    /// can't drift out of sync with the spring, whatever size the notch grows from.
    func revealedByNotch() -> some View {
        let smallest = Theme.Motion.contentScale
        let start = Theme.Motion.revealStart
        return visualEffect { content, proxy in
            let own = CGRect(origin: .zero, size: proxy.size)
            let notch = proxy.bounds(of: .named(NotchShape.space)) ?? own
            let inside = own.intersection(notch)
            let fraction = inside.isNull || own.isEmpty ? 0 : (inside.width * inside.height) / (own.width * own.height)
            let shown = min(1, max(0, (fraction - start) / (1 - start)))
            return content
                .opacity(shown)
                .scaleEffect(smallest + (1 - smallest) * shown, anchor: .top)
        }
    }
}
