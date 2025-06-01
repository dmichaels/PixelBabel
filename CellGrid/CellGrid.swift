import CoreGraphics
import Foundation
import SwiftUI
import Utils

@MainActor
class CellGrid: ObservableObject
{
    struct Defaults {
        public static let viewWidth: Int = Screen.initialWidth
        public static let viewHeight: Int = Screen.initialHeight
        public static let viewScale: CGFloat = Screen.initialScale
        public static let viewScaling: Bool = true
        public static let viewTransparency: UInt8 = CellColor.OPAQUE
        public static let cellSize: Int = 43
        public static let cellSizeFit: Bool = true
        public static let cellPadding: Int = 1
        public static let cellShape: CellShape = CellShape.rounded
        public static let cellForeground: CellColor = CellColor.white // CellColor.black
        public static let viewBackground: CellColor = CellColor.dark
    }

    private var _cellGridView: CellGridView? = nil
    private var _cellFactory: Cell.Factory?

    init(cellFactory: Cell.Factory? = nil) {
        self._cellFactory = cellFactory
    }

    func configure(viewWidth: Int = Defaults.viewWidth,
                   viewHeight: Int = Defaults.viewHeight,
                   viewBackground: CellColor,
                   viewTransparency: UInt8,
                   viewScaling: Bool,
                   cellSize: Int,
                   cellPadding: Int,
                   cellSizeFit: Bool,
                   cellShape: CellShape,
                   cellForeground: CellColor,
                   gridColumns: Int,
                   gridRows: Int)
    {
        // Given argument values are assumed always unscaled; we scale, i.e. logical-to-physical-pixel,
        // e.g. one-to-three on iPhone 15, by default, but only if rending rounded rectangles are
        // circles for smoother curves; no need for squares (inset or not).

        self._cellGridView = CellGridView(viewWidth: viewWidth,
                                          viewHeight: viewHeight,
                                          viewBackground: viewBackground,
                                          viewTransparency: Defaults.viewTransparency,
                                          viewScaling: viewScaling,
                                          cellSize: cellSize,
                                          cellPadding: cellPadding,
                                          cellSizeFit: cellSizeFit,
                                          cellShape: cellShape,
                                          cellForeground: cellForeground,
                                          gridColumns: gridColumns,
                                          gridRows: gridRows,
                                          gridCellFactory: self._cellFactory)
    }

    public var viewScale: CGFloat {
        self._cellGridView!.viewScale
    }

    public var cellGridView: CellGridView? {
        self._cellGridView
    }

    public func normalizedPoint(screenPoint: CGPoint,
                                gridOrigin viewOrigin: CGPoint,
                                orientation: OrientationObserver) -> CGPoint {
        return self._cellGridView!.normalizedPoint(screenPoint: screenPoint, viewOrigin: viewOrigin, orientation: orientation)
    }

    public func onTap(_ viewPoint: CGPoint) {
        if let cellGridView = self._cellGridView { cellGridView.onTap(viewPoint) }
    }

    public func onLongTap(_ viewPoint: CGPoint) {
        if let cellGridView = self._cellGridView { cellGridView.onLongTap(viewPoint) }
    }

    public func onDoubleTap() {
        if let cellGridView = self._cellGridView { cellGridView.onDoubleTap() }
    }

    public func onDrag(_ viewPoint: CGPoint) {
        if let cellGridView = self._cellGridView { cellGridView.onDrag(viewPoint) }
    }

    public func onDragEnd(_ viewPoint: CGPoint) {
        if let cellGridView = self._cellGridView { cellGridView.onDragEnd(viewPoint) }
    }

    public func onZoom(_ zoomFactor: CGFloat) {
        if let cellGridView = self._cellGridView { cellGridView.onZoom(zoomFactor) }
    }

    public func onZoomEnd(_ zoomFactor: CGFloat) {
        if let cellGridView = self._cellGridView { cellGridView.onZoomEnd(zoomFactor) }
    }

    public var image: CGImage? {
        self._cellGridView?.image
    }

    public func run() {
    }
}
