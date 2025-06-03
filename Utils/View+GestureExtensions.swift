import SwiftUI

// N.B. This was inspired by ChatGPT.
//
private struct SmartGestureModifier: ViewModifier
{
    let threshold: CGFloat
    let onDrag: (CGPoint) -> Void
    let onDragEnd: (CGPoint) -> Void
    let onTap: (CGPoint) -> Void
    let onDoubleTap: () -> Void
    let onLongTap: (CGPoint) -> Void
    let onZoom: (CGFloat) -> Void
    let onZoomEnd: (CGFloat) -> Void

    @State private var dragStart: CGPoint? = nil
    @State private var dragging: Bool = false

    public func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if (dragging) {
                        onDrag(value.location)
                    }
                    else {
                        if (dragStart == nil) { dragStart = value.location }
                        if (SmartGestureModifier.dragDistance(start: dragStart!, current: value.location) > threshold) {
                            dragging = true
                            onDrag(value.location)
                        }
                    }
                }
                .onEnded { value in
                    dragging ? onDragEnd(value.location) : onTap(value.location)
                    dragStart = nil
                    dragging = false
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded(onDoubleTap)
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 1.0)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onEnded { value in
                    switch value {
                        case .second(true, let drag):
                            if let location = drag?.location {
                                onLongTap(location)
                            }
                        default:
                            break
                    }
                }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged(onZoom)
                .onEnded(onZoomEnd)
        )
    }

    private static func dragDistance(start: CGPoint, current: CGPoint) -> CGFloat {
        return hypot(current.x - start.x, current.y - start.y)
    }
}

public extension View {
    func onSmartGesture(threshold: CGFloat = 10,
                        onDrag: @escaping (CGPoint) -> Void = { _ in },
                        onDragEnd: @escaping (CGPoint) -> Void = { _ in },
                        onTap: @escaping (CGPoint) -> Void = { _ in },
                        onDoubleTap: @escaping () -> Void = {},
                        onLongTap: @escaping (CGPoint) -> Void = { _ in },
                        onZoom: @escaping (CGFloat) -> Void = { _ in },
                        onZoomEnd: @escaping (CGFloat) -> Void = { _ in }
    ) -> some View {
        self.modifier(SmartGestureModifier(threshold: threshold,
                                           onDrag: onDrag,
                                           onDragEnd: onDragEnd,
                                           onTap: onTap,
                                           onDoubleTap: onDoubleTap,
                                           onLongTap: onLongTap,
                                           onZoom: onZoom,
                                           onZoomEnd: onZoomEnd))
    }
}
