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
        public static let cellSize: Int = 43 // 51
        public static let cellSizeNeat: Bool = true
        public static let cellPadding: Int = 1
        //
        // TODO: while dragging make the shape inset rather than rounded (or circle) for speed.
        // For example generating grid-view with rounded is like 0.074 vs inset is like 0.018.
        // But tricker as it implies no scaling so different/smaller buffer size (the point).
        //
        public static let cellShape: CellShape = CellShape.rounded
        public static let cellColorMode: CellColorMode = CellColorMode.color
        public static let cellForeground: CellColor = CellColor(Color.teal) // CellColor.black
        public static let cellBackground: CellColor = CellColor(40, 40, 40)
        public static let colorSpace = CGColorSpaceCreateDeviceRGB()
        public static let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
    }

    private var _gridColumns: Int = 12
    private var _gridRows: Int = 21
    private var _cellGridView: CellGridView? = nil
    private var _cellFactory: Cell.Factory?
    private var _dragStart: CellLocation? = nil
    private var _dragStartShifted: CellLocation? = nil

    private var _zoomStartCellSize: Int? = nil
    private var _zoomStartShifted: CellLocation? = nil
    private var _zoomStartViewColumns: Int? = nil
    private var _zoomStartViewRows: Int? = nil
    private var _zoomer: CellGridView.Zoom? = nil

    init(cellFactory: Cell.Factory? = nil) {
        self._cellFactory = cellFactory
    }

    func configure(screen: Screen,
                   displayWidth: Int = Defaults.displayWidth,
                   displayHeight: Int = Defaults.displayHeight,
                   cellSize: Int = Defaults.cellSize,
                   cellSizeNeat: Bool = Defaults.cellSizeNeat,
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
                                          cellFit: cellSizeNeat,
//                                        cellFit: false, // cellSizeNeat,
                                          cellShape: cellShape,
                                          gridColumns: self._gridColumns,
                                          gridRows: self._gridRows,
                                          gridCellFactory: self._cellFactory)


        if let cells = self._cellGridView {
            for cell in cells.gridCells {
                if let lifeCell: LifeCell = cells.gridCell(cell.x, cell.y) {

                    // Testing ... 
                    if      ((lifeCell.x == 3) && (lifeCell.y == 3)) { // shift -1 unscaled | blue
                        lifeCell.foreground = CellColor(Color.blue)
                    }
                    else if ((lifeCell.x == 4) && (lifeCell.y == 3)) { // shift +1 unscaled | red
                        lifeCell.foreground = CellColor(Color.red)
                    }
                    else if ((lifeCell.x == 3) && (lifeCell.y == 4)) { // resize -1 unscaled | green
                        lifeCell.foreground = CellColor(Color.green)
                    }
                    else if ((lifeCell.x == 4) && (lifeCell.y == 4)) { // resize +1 unscaled | purple
                        lifeCell.foreground = CellColor(Color.purple)
                    }
                    else if ((lifeCell.x == 3) && (lifeCell.y == 5)) { // shift -1 scaled | dark blue
                        lifeCell.foreground = CellColor(CellColor.darken(Color.blue))
                    }
                    else if ((lifeCell.x == 4) && (lifeCell.y == 5)) { // shift +1 scaled | dark red
                        lifeCell.foreground = CellColor(CellColor.darken(Color.red))
                    }
                    else if ((lifeCell.x == 3) && (lifeCell.y == 6)) { // resize -1 scaled | dark green
                        lifeCell.foreground = CellColor(CellColor.darken(Color.green))
                    }
                    else if ((lifeCell.x == 4) && (lifeCell.y == 6)) { // resize +1 scaled | dark purple
                        lifeCell.foreground = CellColor(CellColor.darken(Color.purple))
                    }
                    else if ((lifeCell.x == 5) && (lifeCell.y == 7)) { // toggle scaled | yellow
                        lifeCell.foreground = CellColor(Color.yellow)
                    }
                    // Testing ... 

                    else  if (lifeCell.x == 0) {
                        lifeCell.foreground = CellColor(Color.blue)
                    }
                    else if (lifeCell.x == 1) {
                        lifeCell.foreground = CellColor(Color.purple)
                    }
                    else if (lifeCell.x == 7) {
                        lifeCell.foreground = CellColor(Color.mint)
                    }
                    else if (lifeCell.x == 8) {
                        lifeCell.foreground = CellColor(Color.green)
                    }
                    else if (lifeCell.x == 9) {
                        lifeCell.foreground = CellColor(Color.red)
                    }
                    else if (lifeCell.x == 10) {
                        lifeCell.foreground = CellColor(Color.yellow)
                    }
                    else if (lifeCell.x == 11) {
                        lifeCell.foreground = CellColor(Color.orange)
                    }
                    else {
                        lifeCell.foreground = CellColor.white
                    }
                }
            }
            cells.shift(shiftx: 0, shifty: 0)
        }

    }

    public var displayScale: CGFloat {
        self._cellGridView!.viewScale
    }

    public func normalizedPoint(screenPoint: CGPoint,
                                gridOrigin viewOrigin: CGPoint,
                                orientation: OrientationObserver) -> CGPoint {
        return self._cellGridView!.normalizedPoint(screenPoint: screenPoint, viewOrigin: viewOrigin, orientation: orientation)
    }

    public func onDrag(_ location: CGPoint) {
        if let cells = self._cellGridView {
            if (self._dragStartShifted == nil) {
                self._dragStart = CellLocation(location)
                self._dragStartShifted = cells.shifted
            }
            else {
                let dragLocation = CellLocation(location)
                let dragDeltaX = self._dragStart!.x - dragLocation.x
                let dragDeltaY = self._dragStart!.y - dragLocation.y
                let dragGridShiftX =  self._dragStartShifted!.x - dragDeltaX
                let dragGridShiftY = self._dragStartShifted!.y - dragDeltaY
                cells.shift(shiftx: dragGridShiftX, shifty: dragGridShiftY)
            }
        }
    }

    public func onDragEnd(_ location: CGPoint) {
        self._dragStart = nil
        self._dragStartShifted = nil
    }

    public func onTap(_ location: CGPoint) {
        if let cellGridView = self._cellGridView {
            if let cell: LifeCell = cellGridView.gridCell(viewPoint: location) {
                let increment: Int = 1
                if      ((cell.x == 3) && (cell.y == 3)) { // shift -1 unscaled | blue
                    cellGridView.shift(shiftx: cellGridView.shifted.x - increment, shifty: cellGridView.shifted.y)
                }
                else if ((cell.x == 4) && (cell.y == 3)) { // shift +1 unscaled | red
                    cellGridView.shift(shiftx: cellGridView.shifted.x + increment, shifty: cellGridView.shifted.y)
                }
                else if ((cell.x == 3) && (cell.y == 4)) { // resize -1 unscaled | green
                    let cellSize: Int = cellGridView.cellSize - increment
                    // let (shiftX, shiftY) = CellGridView.Zoom.calculateShiftForResizeCells(cellGridView: cellGridView, cellSize: cellSize, scaled: false)
                    // cellGridView.resizeCells(cellSize: cellSize, shiftX: shiftX, shiftY: shiftY, scaled: false)
                    cellGridView.resizeCells(cellSize: cellSize, adjustShift: true, scaled: false)
                }
                else if ((cell.x == 4) && (cell.y == 4)) { // resize +1 unscaled | purple
                    let cellSize: Int = cellGridView.cellSize + increment
                    // let (shiftX, shiftY) = CellGridView.Zoom.calculateShiftForResizeCells(cellGridView: cellGridView, cellSize: cellSize, scaled: false)
                    // cellGridView.resizeCells(cellSize: cellSize, shiftX: shiftX, shiftY: shiftY, scaled: false)
                    cellGridView.resizeCells(cellSize: cellSize, adjustShift: true, scaled: false)
                }
                else if ((cell.x == 3) && (cell.y == 5)) { // shift -1 scaled | dark blue
                    cellGridView.shift(shiftx: cellGridView.shifted(scaled: true).x - increment, shifty: cellGridView.shifted(scaled: true).y, scaled: true)
                }
                else if ((cell.x == 4) && (cell.y == 5)) { // shift +1 scaled | dark red
                    cellGridView.shift(shiftx: cellGridView.shifted(scaled: true).x + increment, shifty: cellGridView.shifted(scaled: true).y, scaled: true)
                }
                else if ((cell.x == 3) && (cell.y == 6)) { // resize -1 scaled | dark green
                    let cellSize: Int = cellGridView.cellSizeScaled - increment
                    let (shiftX, shiftY) = CellGridView.Zoom.calculateShiftForResizeCells(cellGridView: cellGridView, cellSize: cellSize, scaled: true)
                    cellGridView.resizeCells(cellSize: cellSize, shiftX: shiftX, shiftY: shiftY, scaled: true)
                }
                else if ((cell.x == 4) && (cell.y == 6)) { // resize +1 scaled | dark purple
                    let cellSize: Int = cellGridView.cellSizeScaled + increment
                    let (shiftX, shiftY) = CellGridView.Zoom.calculateShiftForResizeCells(cellGridView: cellGridView, cellSize: cellSize, scaled: true)
                    cellGridView.resizeCells(cellSize: cellSize, shiftX: shiftX, shiftY: shiftY, scaled: true)
                }
                else if ((cell.x == 5) && (cell.y == 7)) { // toggle scaled | yellow
                    cellGridView.viewScaling = !cellGridView.viewScaling
                }
                else {
                    cell.toggle()
                    cell.write()
                }
            }
        }
    }

    public func onZoom(_ zoom: CGFloat) {
        if let zoomer: CellGridView.Zoom = self._zoomer {
            zoomer.zoom(zoom)
        }
        else if let cellGridView: CellGridView = self._cellGridView {
            self._zoomer = CellGridView.Zoom.start(cellGridView: cellGridView, zoom: zoom, scaled: true)
        }
    }

    public func onZoomEnd(_ zoom: CGFloat) {
        if let zoomer: CellGridView.Zoom = self._zoomer {
            self._zoomer = zoomer.end(zoom)
        }
    }

    public func locate(_ screenPoint: CGPoint) -> CellLocation? {
        if let cells = self._cellGridView {
            return cells.gridCellLocation(viewPoint: screenPoint)
        }
        return nil
    }

    func testingLife() {
        if let cells = self._cellGridView {
            cells.nextGeneration()
        }
    }

    public var image: CGImage? {
        self._cellGridView?.image
    }
}
