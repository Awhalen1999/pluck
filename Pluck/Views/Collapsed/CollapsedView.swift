//
//  CollapsedView.swift
//  Pluck
//
//  Created by Alex Whalen on 2025-12-10.
//

import SwiftUI

/// Public wrapper for the collapsed icon state
struct CollapsedView: View {
    var body: some View {
        CollapsedBody()
    }
}

// MARK: - Preview

#Preview {
    CollapsedView()
        .environment(WindowManager())
        .frame(width: 50, height: 50)
        .background(Theme.backgroundSolid)
}
