import SwiftUI

// Consolidated various gestures. Usage like thisa:
//  
//    .onSmartGesture(dragThreshold: self.dragThreshold,
//                    normalizePoint: self.normalizePoint,
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

    internal let dragThreshold: CGFloat
    internal let swipeThreshold: CGFloat
    internal let normalizePoint: ((CGPoint) -> CGPoint)?
    internal let orientation: OrientationObserver?
    internal let onDrag: (CGPoint) -> Void
    internal let onDragEnd: (CGPoint) -> Void
    internal let onTap: (CGPoint) -> Void
    internal let onDoubleTap: () -> Void
    internal let onLongTap: (CGPoint) -> Void
    internal let onZoom: (CGFloat) -> Void
    internal let onZoomEnd: (CGFloat) -> Void
    internal let onSwipeLeft: (() -> Void)?
    internal let onSwipeRight: (() -> Void)?

    @State private var dragStart: CGPoint? = nil
    @State private var dragging: Bool = false

    public func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if (dragging) {
                        self.onDrag(normalizePoint?(value.location) ?? value.location)
                    }
                    else {
                        if (dragStart == nil) { dragStart = value.location }
                        if (SmartGesture.dragDistance(start: dragStart!, current: value.location) > self.dragThreshold) {
                            dragging = true
                            self.onDrag(normalizePoint?(value.location) ?? value.location)
                        }
                    }
                }
                .onEnded { value in
                    if ((onSwipeLeft != nil) || (onSwipeRight != nil)) {
                        let upsideDown: Bool = (
                            (self.orientation != nil) &&
                            (self.orientation!.current == .portraitUpsideDown)
                        )
                        let upsideDownButNotActuallySupported: Bool = (
                            upsideDown &&
                            !self.orientation!.supported.contains(.portraitUpsideDown)
                        )
                        if (!upsideDownButNotActuallySupported) {
                            let swipeDistance: CGFloat = upsideDown ? value.translation.width : value.translation.width
                            if (swipeDistance < -self.swipeThreshold) {
                                self.onSwipeLeft?()
                            }
                            else if (swipeDistance > self.swipeThreshold) {
                                self.onSwipeRight?()
                            }
                        }
                    }
                    dragging ? self.onDragEnd(normalizePoint?(value.location) ?? value.location)
                             : self.onTap(normalizePoint?(value.location) ?? value.location)
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
                                self.onLongTap(normalizePoint?(location) ?? location)
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
    func onSmartGesture(dragThreshold: Int = 10,
                        swipeThreshold: Int = 100,
                        normalizePoint: ((CGPoint) -> CGPoint)? = nil,
                        orientation: OrientationObserver? = nil,
                        onDrag: @escaping (CGPoint) -> Void = { _ in },
                        onDragEnd: @escaping (CGPoint) -> Void = { _ in },
                        onTap: @escaping (CGPoint) -> Void = { _ in },
                        onDoubleTap: @escaping () -> Void = {},
                        onLongTap: @escaping (CGPoint) -> Void = { _ in },
                        onZoom: @escaping (CGFloat) -> Void = { _ in },
                        onZoomEnd: @escaping (CGFloat) -> Void = { _ in },
                        onSwipeLeft: (() -> Void)? = nil,
                        onSwipeRight: (() -> Void)? = nil,
    ) -> some View {
        self.modifier(SmartGesture(dragThreshold: CGFloat(dragThreshold),
                                   swipeThreshold: CGFloat(swipeThreshold),
                                   normalizePoint: normalizePoint,
                                   orientation: orientation,
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
