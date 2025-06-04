import SwiftUI

// Consolidated various gestures. Usage like thisa:
//  
//    .onSmartGesture(threshold: self.dragThreshold,
//                    normalize: self.normalizePoint,
//        onDrag:      { value in self.onDrag(value) },
//        onDragEnd:   { value in self.onDragEnd(value) },
//        onTap:       { value in self.onTap(value) },
//        onDoubleTap: { self.onDoubleTap() },
//        onLongTap:   { value in self.onLongTap(value) },
//        onZoom:      { value in self.onZoom(value) },
//        onZoomEnd:   { value in self.onZoomEnd(value) }
//    )
//
// N.B. This was inspired by ChatGPT.
//
private struct SmartGesture: ViewModifier
{
    let threshold: CGFloat
    let normalize: ((CGPoint) -> CGPoint)?
    let onDrag: (CGPoint) -> Void
    let onDragEnd: (CGPoint) -> Void
    let onTap: (CGPoint) -> Void
    let onDoubleTap: () -> Void
    let onLongTap: (CGPoint) -> Void
    let onZoom: (CGFloat) -> Void
    let onZoomEnd: (CGFloat) -> Void
    let onSwipeLeft: (() -> Void)?
    let onSwipeRight: (() -> Void)?
    private let swipeDistanceThreshold: CGFloat = 100

    @State private var dragStart: CGPoint? = nil
    @State private var dragging: Bool = false

    public func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if (dragging) {
                        self.onDrag(normalize?(value.location) ?? value.location)
                    }
                    else {
                        if (dragStart == nil) { dragStart = value.location }
                        if (SmartGesture.dragDistance(start: dragStart!, current: value.location) > threshold) {
                            dragging = true
                            self.onDrag(normalize?(value.location) ?? value.location)
                        }
                    }
                }
                .onEnded { value in
                    if ((onSwipeLeft != nil) || (onSwipeRight != nil)) {
                        let swipeDistance: CGFloat = value.translation.width
                        if (swipeDistance < -swipeDistanceThreshold) {
                            self.onSwipeLeft?()
                        }
                        else if (swipeDistance > swipeDistanceThreshold) {
                            self.onSwipeRight?()
                        }
                    }
                    dragging ? self.onDragEnd(normalize?(value.location) ?? value.location)
                             : self.onTap(normalize?(value.location) ?? value.location)
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
                                self.onLongTap(normalize?(location) ?? location)
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
                        normalize: ((CGPoint) -> CGPoint)? = nil,
                        onDrag: @escaping (CGPoint) -> Void = { _ in },
                        onDragEnd: @escaping (CGPoint) -> Void = { _ in },
                        onTap: @escaping (CGPoint) -> Void = { _ in },
                        onDoubleTap: @escaping () -> Void = {},
                        onLongTap: @escaping (CGPoint) -> Void = { _ in },
                        onZoom: @escaping (CGFloat) -> Void = { _ in },
                        onZoomEnd: @escaping (CGFloat) -> Void = { _ in },
                        onSwipeLeft: (() -> Void)? = nil,
                        onSwipeRight: (() -> Void)? = nil
    ) -> some View {
        self.modifier(SmartGesture(threshold: threshold,
                                   normalize: normalize,
                                   onDrag: onDrag,
                                   onDragEnd: onDragEnd,
                                   onTap: onTap,
                                   onDoubleTap: onDoubleTap,
                                   onLongTap: onLongTap,
                                   onZoom: onZoom,
                                   onZoomEnd: onZoomEnd,
                                   onSwipeLeft: onSwipeLeft,
                                   onSwipeRight: onSwipeRight))
    }
}
