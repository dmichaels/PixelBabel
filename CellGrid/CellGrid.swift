import CoreGraphics
import Foundation
import SwiftUI
import Utils

@MainActor
class CellGrid: ObservableObject
{
    struct Defaults {
        public static let displayWidth: Int = Screen.initialWidth
        public static let displayHeight: Int = Screen.initialHeight
        public static let displayScale: CGFloat = Screen.initialScale
        public static let displayScaling: Bool = true
        public static let displayTransparency: UInt8 = CellColor.OPAQUE
        public static let cellSize: Int = 43 // 33 // 43 // 51 // ... resizing up/down 33 is all good it seems
        public static let cellSizeFit: Bool = true
        public static let cellPadding: Int = 1
        //
        // TODO: while dragging make the shape inset rather than rounded (or circle) for speed.
        // For example generating grid-view with rounded is like 0.074 vs inset is like 0.018.
        // But tricker as it implies no scaling so different/smaller buffer size (the point).
        //
        public static let cellShape: CellShape = CellShape.rounded
        public static let cellColorMode: CellColorMode = CellColorMode.color
        public static let cellForeground: CellColor = CellColor.white // CellColor.black
        public static let cellBackground: CellColor = CellColor.dark
    }

    private var _gridColumns: Int = 120
    private var _gridRows: Int = 210
    private var _cellGridView: CellGridView? = nil
    private var _cellFactory: Cell.Factory?
    private var _dragger: CellGridView.Drag? = nil
    private var _zoomer: CellGridView.Zoom? = nil
    private var _pickerMode: Bool = false
    private var _dragCell: Cell? = nil

    init(cellFactory: Cell.Factory? = nil) {
        self._cellFactory = cellFactory
    }

    func configure(screen: Screen,
                   displayWidth: Int = Defaults.displayWidth,
                   displayHeight: Int = Defaults.displayHeight,
                   cellSize: Int = Defaults.cellSize,
                   cellSizeFit: Bool = Defaults.cellSizeFit,
                   cellPadding: Int = Defaults.cellPadding,
                   cellShape: CellShape = Defaults.cellShape,
                   cellColorMode: CellColorMode = Defaults.cellColorMode,
                   cellForeground: CellColor = Defaults.cellForeground,
                   cellBackground: CellColor = Defaults.cellBackground,
                   displayScaling: Bool = Defaults.displayScaling)
    {
        // Given argument values are assumed always unscaled; we scale, i.e. logical-to-physical-pixel,
        // e.g. one-to-three on iPhone 15, by default, but only if rending rounded rectangles are
        // circles for smoother curves; no need for squares (inset or not).

        self._cellGridView = CellGridView(viewWidth: displayWidth,
//      self._cellGridView = CellGridView(viewWidth: 397, // displayWidth,
                                          viewHeight: displayHeight,
                                          viewBackground: cellBackground,
                                          viewTransparency: Defaults.displayTransparency,
                                          viewScaling: displayScaling,
                                          cellSize: cellSize,
                                          cellPadding: cellPadding,
                                          cellFit: cellSizeFit,
                                          cellShape: cellShape,
                                          gridColumns: self._gridColumns,
                                          gridRows: self._gridRows,
                                          gridCellFactory: self._cellFactory)
    }

    public var displayScale: CGFloat {
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
        if let cellGridView = self._cellGridView {
            if let cell: Cell = cellGridView.gridCell(viewPoint: viewPoint) {
                if ((cell.x == 0) && (cell.y == 0)) {
                    if (self._pickerMode) {
                        self._pickerMode = false
                        cell.write(foreground: CellColor(Color.green))
                    }
                    else {
                        self._pickerMode = true
                        cell.write(foreground: CellColor(Color.red))
                    }
                }
                else {
                    cell.select()
                }
            }
        }
    }

    public func onLongTap(_ viewPoint: CGPoint) {
    }

    public func onDrag(_ viewPoint: CGPoint) {
        guard let dragger: CellGridView.Drag = self._dragger else {
            if let cellGridView = self._cellGridView {
                self._dragger = CellGridView.Drag(cellGridView, viewPoint, picker: self._pickerMode)
            }
            return
        }
        dragger.drag(viewPoint)
    }

    public func onDragEnd(_ viewPoint: CGPoint) {
        if let dragger: CellGridView.Drag = self._dragger {
            dragger.end(viewPoint)
            self._dragger = nil
        }
    }

    public func onZoom(_ zoomFactor: CGFloat) {
        guard let zoomer: CellGridView.Zoom = self._zoomer else {
            if let cellGridView = self._cellGridView {
                self._zoomer = CellGridView.Zoom(cellGridView, zoomFactor)
            }
            return
        }
        zoomer.zoom(zoomFactor)
    }

    public func onZoomEnd(_ zoomFactor: CGFloat) {
        if let zoomer: CellGridView.Zoom = self._zoomer {
            self._zoomer = zoomer.end(zoomFactor)
            self._zoomer = nil
        }
    }

    public func onDoubleTap() {
        self._pickerMode = !self._pickerMode
    }

    public func locate(_ screenPoint: CGPoint) -> CellLocation? {
        if let cells = self._cellGridView {
            return cells.gridCellLocation(viewPoint: screenPoint)
        }
        return nil
    }

    public var image: CGImage? {
        self._cellGridView?.image
    }
}
