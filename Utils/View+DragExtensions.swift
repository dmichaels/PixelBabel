// N.B. This was written wholesale by ChatGPT.

import SwiftUI

// MARK: - Utility Function

private func dragDistance(start: CGPoint, current: CGPoint) -> CGFloat {
    let dx = current.x - start.x
    let dy = current.y - start.y
    return hypot(dx, dy)
}

// MARK: - Drag Threshold Modifier

public struct DragThresholdModifier: ViewModifier {
    let threshold: CGFloat
    let onDrag: (CGPoint) -> Void
    let onDragEnd: (CGPoint) -> Void
    let onTap: (CGPoint) -> Void

    @State private var startPoint: CGPoint? = nil
    @State private var dragging = false

    public func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let point = value.location
                    if startPoint == nil { startPoint = point }
                    if let start = startPoint, !dragging, dragDistance(start: start, current: point) > threshold {
                        dragging = true
                        onDrag(point)
                    }
                    if dragging {
                        onDrag(point)
                    }
                }
                .onEnded { value in
                    if dragging {
                        onDragEnd(value.location)
                    }
                    else {
                        onTap(value.location)
                    }
                    startPoint = nil
                    dragging = false
                }
        )
    }
}

// MARK: - View Extension

public extension View {
    /// Adds a drag gesture with a configurable threshold before triggering the drag callbacks.
    ///
    /// - Parameters:
    ///   - threshold: Minimum distance in points to recognize as a drag.
    ///   - onDrag: Called as the drag changes after threshold exceeded.
    ///   - onDragEnd: Called when the drag ends after threshold exceeded.
    ///   - onTap: Called when this is actually just a tap not a drag.
    func onSmartDrag(
        threshold: CGFloat = 10,
        onDrag: @escaping (CGPoint) -> Void = { _ in },
        onDragEnd: @escaping (CGPoint) -> Void = { _ in },
        onTap: @escaping (CGPoint) -> Void = { _ in }
    ) -> some View {
        self.modifier(DragThresholdModifier(
            threshold: threshold,
            onDrag: onDrag,
            onDragEnd: onDragEnd,
            onTap: onTap
        ))
    }
}
