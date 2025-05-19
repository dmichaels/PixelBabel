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
        public static let cellSize: Int = 45 // 51
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
    private var _zoomStartShiftedBy: CellLocation? = nil
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
                                          viewHeight: displayHeight,
                                          viewBackground: cellBackground,
                                          viewTransparency: Defaults.displayTransparency,
                                          viewScaling: displayScaling,
                                          cellSize: cellSize,
                                          cellPadding: cellPadding,
                                          cellFit: cellSizeNeat,
                                          cellShape: cellShape,
                                          gridColumns: self._gridColumns,
                                          gridRows: self._gridRows,
                                          gridCellFactory: self._cellFactory)


        if let cells = self._cellGridView {
            for cell in cells.gridCells {
                if let lifeCell: LifeCell = cells.gridCell(cell.x, cell.y) {
                    if (lifeCell.x == 0) {
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
                                orientation: OrientationObserver) -> CGPoint
    {
        return self._cellGridView!.normalizedPoint(screenPoint: screenPoint, viewOrigin: viewOrigin, orientation: orientation)
    }

    public func onDrag(_ location: CGPoint) {
        if let cells = self._cellGridView {
            if (self._dragStartShifted == nil) {
                self._dragStart = CellLocation(location)
                self._dragStartShifted = cells.shiftedBy
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
            if let cell: LifeCell = cellGridView.gridCell(location) {
                if (((cell.x == 0) && (cell.y == 0)) || ((cell.x == 3) && (cell.y == 3))) {
                    let cellSizeIncrement: Int = 1
                    let cellSize: Int = cellGridView.cellSizeScaled + cellSizeIncrement
                    let (shiftX, shiftY) = cellGridView.calculateShiftForCellResizeScaled(cellSize: cellSize)
                    cellGridView.setCellSizeScaled(cellSize: cellSize, shiftX: shiftX, shiftY: shiftY)
                }
                else if cell.x == 1 && cell.y == 1 {
                    // cellGridView.resizeCells(cellSizeIncrement: -1)
                    let cellSizeIncrement: Int = -1
                    let cellSize: Int = cellGridView.cellSizeScaled + cellSizeIncrement
                    let (shiftX, shiftY) = cellGridView.calculateShiftForCellResizeScaled(cellSize: cellSize)
                    cellGridView.setCellSizeScaled(cellSize: cellSize, shiftX: shiftX, shiftY: shiftY)
                }
                else if cell.x == 2 && cell.y == 2 {
                    cellGridView.viewScaling = !cellGridView.viewScaling
                }
                else {
                    cell.toggle()
                    cell.write()
                }
            }
        }
    }

    public func old_unscaled_onZoom(_ zoom: CGFloat) {
        if zoom != 1.0, let cellGridView = self._cellGridView {
            if (self._zoomStartCellSize == nil) {
                self._zoomStartCellSize = cellGridView.cellSize
                self._zoomStartShiftedBy = cellGridView.shiftedBy
                self._zoomStartViewColumns = cellGridView.viewColumns
                self._zoomStartViewRows = cellGridView.viewRows
            }
            let cellSizeZoomed: CGFloat = CGFloat(self._zoomStartCellSize!) * zoom
            let cellSize: Int = Int(cellSizeZoomed.rounded(FloatingPointRoundingRule.toNearestOrEven))
            let cellSizeIncrement: Int = cellSize - self._zoomStartCellSize!
            //
            // TODO
            // If blank space then adjust shift here accordingly.
            // Already changing shift in response to zoom based on number of rows/columns
            // so the zoom feels more centered, but have not yet taken this case into account.
            //
            let shiftX: Int = self._zoomStartShiftedBy!.x - (cellSizeIncrement * (self._zoomStartViewColumns! / 2))
            let shiftY: Int = self._zoomStartShiftedBy!.y - (cellSizeIncrement * (self._zoomStartViewRows! / 2))
            // print("ZOOM: \(zoom) > zoomStartCellSize: \(self._zoomStartCellSize!) currentCellSize: \(cellGridView.cellSize) cellSize: \(cellSize)")
            cellGridView.setCellSize(cellSize: cellSize, shiftX: shiftX, shiftY: shiftY)
        }
    }

    public func old_onZoom(_ zoom: CGFloat) {
        if zoom != 1.0, let cellGridView = self._cellGridView {
            if (self._zoomStartCellSize == nil) {
                self._zoomStartCellSize = cellGridView.cellSizeScaled
                self._zoomStartShiftedBy = cellGridView.shiftedByScaled
                self._zoomStartViewColumns = cellGridView.viewColumns
                self._zoomStartViewRows = cellGridView.viewRows
            }
            let cellSizeZoomed: CGFloat = CGFloat(self._zoomStartCellSize!) * zoom
            let cellSize: Int = Int(cellSizeZoomed.rounded(FloatingPointRoundingRule.toNearestOrEven))
            let cellSizeIncrement: Int = cellSize - self._zoomStartCellSize!
            //
            // TODO
            // If blank space then adjust shift here accordingly.
            // Already changing shift in response to zoom based on number of rows/columns
            // so the zoom feels more centered, but have not yet taken this case into account.
            //
            // let shiftX: Int = self._zoomStartShiftedBy!.x - (cellSizeIncrement * (self._zoomStartViewColumns!) / 2)
            // let shiftY: Int = self._zoomStartShiftedBy!.y - (cellSizeIncrement * (self._zoomStartViewRows!) / 2)
            // let shiftX: Int = self._zoomStartShiftedBy!.x - (cellSizeIncrement * (self._zoomStartViewColumns! / 2))
            // let shiftY: Int = self._zoomStartShiftedBy!.y - (cellSizeIncrement * (self._zoomStartViewRows! / 2))
            let shiftX: Int = self._zoomStartShiftedBy!.x - (cellSizeIncrement * ((self._zoomStartViewColumns! + 0) / 2))
            let shiftY: Int = self._zoomStartShiftedBy!.y - (cellSizeIncrement * ((self._zoomStartViewRows! + 0) / 2))
            print("ZOOM: \(zoom) > zoomStartCellSize: \(self._zoomStartCellSize!) currentCellSize: \(cellGridView.cellSizeScaled) cellSize: \(cellSize) zoomStartShiftedBy: \(self._zoomStartShiftedBy!) shift: [\(shiftX),\(shiftY)]")
            cellGridView.setCellSizeScaled(cellSize: cellSize, shiftX: shiftX, shiftY: shiftY)
        }
    }

    public func old_onZoomEnd(_ zoom: CGFloat) {
        self.onZoom(zoom)
        self._zoomStartCellSize = nil
        self._zoomStartShiftedBy = nil
        self._zoomStartViewColumns = nil
        self._zoomStartViewRows = nil
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
            return cells.gridCellLocation(screenPoint)
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
