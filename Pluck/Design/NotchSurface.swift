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

/// What the expanded notch is made of. Both stay pure black level with the
/// hardware notch, so the two always read as one piece.
enum NotchMaterial: String, CaseIterable {
    /// Solid black all the way down.
    case solid
    /// Black at the top, fading into translucent dark glass below.
    case glass
}

extension View {
    /// Fills the view with the notch surface, clipped to the notch shape.
    func notchSurface(radius: CGFloat, material: NotchMaterial) -> some View {
        background {
            let shape = NotchShape(radius: radius)
            switch material {
            case .solid:
                shape.fill(Theme.Notch.fill)
            case .glass:
                GeometryReader { proxy in
                    let header = min(1, Theme.Notch.headerHeight / max(proxy.size.height, 1))
                    shape
                        .fill(LinearGradient(stops: [
                            .init(color: Theme.Notch.fill, location: 0),
                            .init(color: Theme.Notch.fill, location: header),
                            .init(color: Theme.Notch.fill.opacity(0.8), location: 1),
                        ], startPoint: .top, endPoint: .bottom))
                        .background(.ultraThinMaterial, in: shape)
                }
            }
        }
    }
}
