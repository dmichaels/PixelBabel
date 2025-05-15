import CoreGraphics
import Foundation
import SwiftUI
import Utils

@MainActor
class CellGrid: ObservableObject
{
    struct Defaults {
        public static let debug: Bool = true
        public static let debugVerbose: Bool = true

        public static let displayWidth: Int = Screen.initialWidth
        public static let displayHeight: Int = Screen.initialHeight
        public static let displayScale: CGFloat = Screen.initialScale
        public static let displayScaling: Bool = true
        public static let displayTransparency: UInt8 = CellColor.OPAQUE
        public static let cellSize: Int = 44 // 51
        public static let cellSizeNeat: Bool = true // TODO/xyzzy
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
        public static let cellLimitUpdate: Bool = true
        public static let colorSpace = CGColorSpaceCreateDeviceRGB()
        public static let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
    }

    private var _displayWidth: Int = Screen.initialWidth
    private var _displayHeight: Int = Screen.initialHeight
    private var _displayScale: CGFloat = Screen.initialScale
    private var _displayScaling: Bool = Defaults.displayScaling
    private var _cellSize: Int = Defaults.cellSize
    private var _cellPadding: Int = Defaults.cellPadding
    private var _cellShape: CellShape = Defaults.cellShape
    private var _cellColorMode: CellColorMode = Defaults.cellColorMode
    private var _cellBackground: CellColor = Defaults.cellBackground
    private var _cellLimitUpdate: Bool = Defaults.cellLimitUpdate
    private var _gridColumns: Int = 12
    private var _gridRows: Int = 21
    private var _cellGridView: CellGridView? = nil
    private var _cellFactory: Cell.Factory?
    private var _dragStart: CellLocation? = nil
    private var _dragStartShifted: CellLocation? = nil

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

        self._displayScale = screen.scale
        self._displayScaling = [CellShape.square, CellShape.inset].contains(cellShape) ? false : displayScaling
        self._displayWidth = self.scaled(displayWidth)
        self._displayHeight = self.scaled(displayHeight)

        self._cellSize = self.scaled(cellSize)
        self._cellPadding = self.scaled(cellPadding)
        self._cellShape = cellShape
        self._cellColorMode = cellColorMode
        self._cellBackground = cellBackground

        let preferredSize = CellGridView.preferredSize(viewWidth: displayWidth, viewHeight: displayHeight,
                                                       cellSize: cellSize, enabled: cellSizeNeat)
        self._cellSize = self.scaled(preferredSize.cellSize)
        self._displayWidth = self.scaled(preferredSize.viewWidth)
        self._displayHeight = self.scaled(preferredSize.viewHeight)

        if (Defaults.debug) { print_debug() }

        self._cellGridView = CellGridView(viewWidth: self._displayWidth,
                                          viewHeight: self._displayHeight,
                                          viewBackground: self._cellBackground,
                                          viewTransparency: Defaults.displayTransparency,
                                          viewScaling: self._displayScaling,
                                          gridColumns: self._gridColumns,
                                          gridRows: self._gridRows,
                                          cellSize: self._cellSize,
                                          cellPadding: self._cellPadding,
                                          cellShape: self._cellShape,
                                          cellFactory: self._cellFactory)

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

        func print_debug() {
            print("SCREEN-SIZE>              \(self.scaled(screen.width)) x \(self.scaled(screen.height))" +
                  (self._displayScaling ? " (UN: \(screen.width) x \(screen.height))" : ""))
            print("SCREEN-SCALE>             \(screen.scale)")
            print("VIEW-SCALING>             \(self._displayScaling)")
            print("VIEW-SIZE-INITIAL>        \(displayWidth) x \(displayHeight)" + (self._displayScaling ? " (UN)" : "") +
                  ((displayWidth != self.unscaled(self._displayWidth) ||
                   displayHeight != self.unscaled(self._displayHeight)
                   ? " -->> PREFERRED: \(self.unscaled(self._displayWidth))" +
                     (" x \(self.unscaled(self._displayHeight))" + (self._displayScaling ? " (UN)" : "")) : "")))
            print("CELL-SIZE-INITIAL>        \(cellSize)" + (self._displayScaling ? " (UN)" : "") +
                   (cellSize != self.unscaled(self._cellSize)
                    ? (" -->> PREFERRED: \(self.unscaled(self._cellSize))" + (self._displayScaling ? " (UN)" : "")) : ""))
            print("VIEW-SIZE>                \(self._displayWidth) x \(self._displayHeight)" +
                  (self._displayScaling ?
                   " (UN: \(self.unscaled(self._displayWidth)) x \(self.unscaled(self._displayHeight)))" : ""))
            print("CELL-SIZE>                \(self._cellSize)" +
                  (self._displayScaling ? " (UN: \(self.unscaled(self._cellSize)))" : ""))
            print("CELL-PADDING>             \(self._cellPadding)" +
                  (self._displayScaling ? " (UN: \(self.unscaled(self._cellPadding)))" : ""))
            print("PREFERRED-SIZING>         \(cellSizeNeat)")
            if (Defaults.debugVerbose && cellSizeNeat) {
                let sizes = CellGridView.preferredSizes(viewWidth: self.unscaled(self._displayWidth),
                                                        viewHeight: self.unscaled(self._displayHeight))
                for size in sizes {
                    print("PREFFERED>" +
                          " CELL-SIZE \(String(format: "%3d", self.scaled(size.cellSize)))" +
                          (self._displayScaling ? " (UN: \(String(format: "%3d", size.cellSize)))" : "") +
                          " VIEW-SIZE: \(String(format: "%3d", self.scaled(size.viewWidth)))" +
                          " x \(String(format: "%3d", self.scaled(size.viewHeight)))" +
                          (self._displayScaling ?
                           " (UN: \(String(format: "%3d", size.viewWidth))" +
                           " x \(String(format: "%3d", size.viewHeight)))" : "") +
                          " MARGINS: \(String(format: "%2d", self._displayWidth - self.scaled(size.viewWidth)))" +
                          " x \(String(format: "%2d", self._displayHeight - self.scaled(size.viewHeight)))" +
                          (self._displayScaling ? (" (UN: \(String(format: "%2d", self.unscaled(self._displayWidth) - size.viewWidth))"
                                                   + "x \(String(format: "%2d", self.unscaled(self._displayHeight) - size.viewHeight)))") : "") +
                          ((size.cellSize == self.unscaled(self._cellSize)) ? " <<<" : ""))
                }
            }
        }
    }

    public var displayScale: CGFloat {
        self._cellGridView!.viewScale
    }

    internal func scaled(_ value: Int) -> Int {
        return self._displayScaling ? Int(round(CGFloat(value) * self._displayScale)) : value
    }

    internal func unscaled(_ value: Int) -> Int {
        self._displayScaling ? Int(round(CGFloat(value) / self._displayScale)) : value
    }

    public func normalizedPoint(screenPoint: CGPoint,
                                gridOrigin: CGPoint,
                                orientation: OrientationObserver) -> CGPoint
    {
        // Various oddities with upside-down mode and having to know the
        // previous orientation and whether or not we are an iPad and whatnot.
        //
        let x, y: CGFloat
        switch orientation.current {
        case .portrait:
            x = screenPoint.x - gridOrigin.x
            y = screenPoint.y - gridOrigin.y
        case .portraitUpsideDown:
            if (orientation.ipad) {
                x = CGFloat(self.unscaled(self._displayWidth)) - 1 - (screenPoint.x - gridOrigin.x)
                y = CGFloat(self.unscaled(self._displayHeight)) - 1 - (screenPoint.y - gridOrigin.y)
            }
            else if (orientation.previous.isLandscape) {
                x = screenPoint.y - gridOrigin.x
                y = CGFloat(self.unscaled(self._displayHeight)) - 1 - (screenPoint.x - gridOrigin.y)
            }
            else {
                x = screenPoint.x - gridOrigin.x
                y = screenPoint.y - gridOrigin.y
            }
        case .landscapeRight:
            x = screenPoint.y - gridOrigin.x
            y = CGFloat(self.unscaled(self._displayHeight)) - 1 - (screenPoint.x - gridOrigin.y)
        case .landscapeLeft:
            x = CGFloat(self.unscaled(self._displayWidth)) - 1 - (screenPoint.y - gridOrigin.x)
            y = screenPoint.x - gridOrigin.y
        default:
            x = screenPoint.x - gridOrigin.x
            y = screenPoint.y - gridOrigin.y
        }
        return CGPoint(x: x, y: y)
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
        if let cells = self._cellGridView {
            if let cell: LifeCell = cells.gridCell(location) {
                if cell.x == 0 && cell.y == 0 {
                    let incrementCellSize = 8
                    self._cellSize += self.scaled(incrementCellSize)
                    self._cellGridView = CellGridView(viewWidth: self._displayWidth,
                                                      viewHeight: self._displayHeight,
                                                      // viewWidth: 400, // for 51
                                                      // viewHeight: 850, // for 51
                                                      viewBackground: self._cellBackground,
                                                      viewTransparency: Defaults.displayTransparency,
                                                      viewScaling: self._displayScaling,
                                                      gridColumns: self._gridColumns,
                                                      gridRows: self._gridRows,
                                                      cellSize: self._cellSize,
                                                      cellPadding: self._cellPadding,
                                                      cellShape: self._cellShape,
                                                      cellFactory: self._cellFactory)
                                                      // cells: self._cellGridView!._cells,
                                                      // buffer: self._cellGridView!._buffer)
                    self._cellGridView!.shift(shiftx: 0, shifty: 0)
                }
                else {
                    cell.toggle()
                    cell.write()
                }
            }
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

/*
    func randomize() {
        if let cells = self._cellGridView {
            CellGrid._randomize(displayWidth: self._displayWidth,
                                displayHeight: self._displayHeight,
                                cellSize: self.cellSize,
                                cellColorMode: self.cellColorMode,
                                cellShape: self.cellShape,
                                cellPadding: self.cellPadding,
                                cellLimitUpdate: self._cellLimitUpdate,
                                background: self.background,
                                cells: cells)
        }
    }
    static func _randomize(displayWidth: Int,
                           displayHeight: Int,
                           cellSize: Int,
                           cellColorMode: CellColorMode,
                           cellShape: CellShape,
                           cellPadding: Int,
                           cellLimitUpdate: Bool,
                           background: CellColor,
                           cells: CellGridView)
    {
        let start = Date()
        for cell in cells.gridCells {
            cell.write(foreground: CellColor.random(), foregroundOnly: cellLimitUpdate)
        }
        let end = Date()
        let elapsed = end.timeIntervalSince(start)
    }
*/

    public var image: CGImage? {
        self._cellGridView?.image
    }
}
