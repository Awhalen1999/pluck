import SwiftUI

/// Every value the UI uses. Views read from here and never hard-code numbers or
/// colors, so the whole app is tuned in one place. Tokens are added as the UI
/// needs them; the full system is reviewed with Alex before the notch states are built.
enum Theme {
    enum Notch {
        /// The panel's fixed size, big enough for the largest state (the Shelf).
        static let canvas = CGSize(width: 720, height: 640)
        /// Bottom corner radius of the idle notch, matched to the hardware notch.
        static let idleRadius: CGFloat = 10
        /// The stand-in for the notch on screens without one.
        static let pillSize = CGSize(width: 160, height: 24)
        static let pillTopInset: CGFloat = 4
        static let fill = Color.black
    }
}
