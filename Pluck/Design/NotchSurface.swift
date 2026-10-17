import SwiftUI

/// The notch's shape: flat against the top of the screen and rounded at the
/// bottom. On a screen without a notch it floats, so the top rounds too.
nonisolated struct NotchShape: Shape {
    var radius: CGFloat
    var topRadius: CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(radius, topRadius) }
        set { (radius, topRadius) = (newValue.first, newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(topLeadingRadius: topRadius, bottomLeadingRadius: radius,
                               bottomTrailingRadius: radius, topTrailingRadius: topRadius, style: .continuous)
            .path(in: rect)
    }
}

extension View {
    /// Puts the view on the notch surface: Liquid Glass, kept pure black level
    /// with the hardware notch so the two read as one piece. Content is clipped
    /// to the shape, so nothing shows outside it while it grows or shrinks.
    func notchSurface(radius: CGFloat, topRadius: CGFloat = 0) -> some View {
        let shape = NotchShape(radius: radius, topRadius: topRadius)
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
}
