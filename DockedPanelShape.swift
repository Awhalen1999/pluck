//
//  DockedPanelShape.swift
//  Pluck
//
//  Custom shape that rounds corners only on the side away from the docked edge
//

import SwiftUI

/// A rounded rectangle that only rounds corners on the free-floating side
/// When docked right: rounds left side only
/// When docked left: rounds right side only
struct DockedPanelShape: Shape {
    var dockedEdge: DockedEdge
    var cornerRadius: CGFloat
    
    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch dockedEdge {
        case .right:
            // Docked to right edge - round LEFT side only
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            
        case .left:
            // Docked to left edge - round RIGHT side only
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(270),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        
        return path
    }
}

// MARK: - Preview

#Preview("Docked Right") {
    DockedPanelShape(dockedEdge: .right, cornerRadius: 14)
        .fill(Theme.backgroundCard)
        .frame(width: 220, height: 400)
        .padding()
        .background(Color.purple.opacity(0.2))
}

#Preview("Docked Left") {
    DockedPanelShape(dockedEdge: .left, cornerRadius: 14)
        .fill(Theme.backgroundCard)
        .frame(width: 220, height: 400)
        .padding()
        .background(Color.purple.opacity(0.2))
}

#Preview("Collapsed Right") {
    DockedPanelShape(dockedEdge: .right, cornerRadius: 12)
        .fill(Theme.backgroundCard)
        .frame(width: 50, height: 50)
        .padding()
        .background(Color.purple.opacity(0.2))
}

#Preview("Collapsed Left") {
    DockedPanelShape(dockedEdge: .left, cornerRadius: 12)
        .fill(Theme.backgroundCard)
        .frame(width: 50, height: 50)
        .padding()
        .background(Color.purple.opacity(0.2))
}
