import SwiftUI

/// The notch. Hanging from the top edge of a notched screen, its top corners
/// flare out into the edge, drawn just outside its frame, so it reads as the
/// hardware notch grown. On a screen without one it floats, rounded all round.
nonisolated struct NotchShape: Shape {
    var radius: CGFloat
    var flare: CGFloat
    var floats = false

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(radius, flare) }
        set { (radius, flare) = (newValue.first, newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        if floats { return Path(roundedRect: rect, cornerRadius: radius, style: .continuous) }
        var path = Path()
        path.move(to: CGPoint(x: rect.minX - flare, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: flare)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX + flare, y: rect.minY), radius: flare)
        path.closeSubpath()
        return path
    }
}
