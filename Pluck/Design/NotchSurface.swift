import SwiftUI

/// The notch's shape: flat against the top of the screen, rounded at the bottom.
nonisolated struct NotchShape: Shape {
    var radius: CGFloat

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
        return clipShape(shape)
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

    /// Fades content in once the notch has mostly opened. `order` staggers
    /// siblings, so a row of tiles arrives as a quick cascade.
    func reveal(order: Int = 0) -> some View {
        modifier(Reveal(order: order))
    }
}

private struct Reveal: ViewModifier {
    let order: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : Theme.Motion.contentScale, anchor: .top)
            .onAppear {
                withAnimation(Theme.Motion.contentIn.delay(Double(order) * Theme.Motion.stagger)) { shown = true }
            }
    }
}
