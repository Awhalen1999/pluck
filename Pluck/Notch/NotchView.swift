import SwiftUI

/// Draws the notch at the top center of the panel's canvas.
struct NotchView: View {
    let controller: NotchController

    var body: some View {
        if let geometry = controller.geometry {
            let radius = geometry.hasNotch ? Theme.Notch.idleRadius : geometry.frame.height / 2
            UnevenRoundedRectangle(topLeadingRadius: geometry.hasNotch ? 0 : radius,
                                   bottomLeadingRadius: radius,
                                   bottomTrailingRadius: radius,
                                   topTrailingRadius: geometry.hasNotch ? 0 : radius)
                .fill(Theme.Notch.fill)
                .frame(width: geometry.frame.width, height: geometry.frame.height)
                .padding(.top, geometry.topInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}
