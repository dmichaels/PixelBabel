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
        public static let displayScaling: Bool = false
        public static let displayTransparency: UInt8 = 255
        public static let cellSize: Int = 42 // 43
        public static let cellSizeNeat: Bool = true
        public static let cellPadding: Int = 1
        public static let cellBleed: Bool = false
        public static let cellShape: CellShape = CellShape.rounded
        public static let cellColorMode: CellColorMode = CellColorMode.color
        public static let cellForeground: CellColor = CellColor.black
        public static let cellBackground: CellColor = CellColor(40, 40, 40)
        public static let cellAntialiasFade: Float = 0.6
        public static let cellRoundedRectangleRadius: Float = 0.25
        public static var cellPreferredSizeMarginMax: Int = 30
        public static let cellLimitUpdate: Bool = true
        public static let colorSpace = CGColorSpaceCreateDeviceRGB()
        public static let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
    }

    private var _displayWidth: Int = Screen.initialWidth
    private var _displayHeight: Int = Screen.initialHeight
    private var _displayWidthUnscaled: Int = Screen.initialWidth
    private var _displayHeightUnscaled: Int = Screen.initialHeight
    private var _displayScale: CGFloat = Screen.initialScale
    private var _displayScaling: Bool = Defaults.displayScaling
    private var _cellSize: Int = Defaults.cellSize
    private var _cellSizeUnscaled: Int = Defaults.cellSize
    private var _cellPadding: Int = Defaults.cellPadding
    private var _cellBleed: Bool = Defaults.cellBleed
    private var _cellShape: CellShape = Defaults.cellShape
    private var _cellColorMode: CellColorMode = Defaults.cellColorMode
    private var _cellBackground: CellColor = Defaults.cellBackground
    private var _cellAntialiasFade: Float = Defaults.cellAntialiasFade
    private var _cellRoundedRectangleRadius: Float = Defaults.cellRoundedRectangleRadius
    private var _cellPreferredSizeMarginMax: Int = Defaults.cellPreferredSizeMarginMax
    private var _cellLimitUpdate: Bool = Defaults.cellLimitUpdate
    private var _cells: Cells? = nil
    private var _cellFactory: Cell.Factory?
    private var _dragCell: Cell? = nil

    init(cellFactory: Cell.Factory? = nil) {
        self._cellFactory = cellFactory
        print("PIXELMAP-CONSTRUCTOR")
    }

    func configure(screen: Screen,
                   displayWidth: Int = Defaults.displayWidth,
                   displayHeight: Int = Defaults.displayHeight,
                   cellSize: Int = Defaults.cellSize,
                   cellSizeNeat: Bool = Defaults.cellSizeNeat,
                   cellPadding: Int = Defaults.cellPadding,
                   cellBleed: Bool = Defaults.cellBleed,
                   cellShape: CellShape = Defaults.cellShape,
                   cellColorMode: CellColorMode = Defaults.cellColorMode,
                   cellForeground: CellColor = Defaults.cellForeground,
                   cellBackground: CellColor = Defaults.cellBackground,
                   displayScaling: Bool = Defaults.displayScaling)
    {
        // Given argument values are assumed always unscaled; we scale, i.e. logical-to-physical-pixel,
        // e.g. one-to-three on iPhone 15, by default, but only if rending rounded rectangles are
        // circles for smoother curves; no need for squares (inset or not).

        print("PIXELMAP-CONFIGURE")
        self._displayScale = screen.scale
        self._displayScaling = [CellShape.square, CellShape.inset].contains(cellShape) ? false : displayScaling
        self._displayWidth = self.scaled(displayWidth)
        self._displayHeight = self.scaled(displayHeight)
        self._displayWidthUnscaled = displayWidth
        self._displayHeightUnscaled = displayHeight

        self._cellSize = self.scaled(cellSize)
        self._cellSizeUnscaled = cellSize
        self._cellPadding = self.scaled(cellPadding)
        self._cellBleed = cellBleed
        self._cellShape = cellShape
        self._cellColorMode = cellColorMode
        self._cellBackground = cellBackground

        let neatCells = Cells.preferredCellSizes(self._displayWidthUnscaled, self._displayHeightUnscaled,
                                                 cellPreferredSizeMarginMax: self._cellPreferredSizeMarginMax)
        if (cellSizeNeat) {
            if let neatCell = Cells.closestPreferredCellSize(in: neatCells, to: self._cellSizeUnscaled) {
                print_debug(neatCells, neatCell, verbose: true)
                self._cellSize = self.scaled(neatCell.cellSize)
                self._displayWidth = self.scaled(neatCell.displayWidth)
                self._displayHeight = self.scaled(neatCell.displayHeight)
                self._displayWidthUnscaled = neatCell.displayWidth
                self._displayHeightUnscaled = neatCell.displayHeight
            }
        }

        self._cells = Cells(grid: self,
                            displayWidth: self._displayWidth,
                            displayHeight: self._displayHeight,
                            displayScale: self._displayScale,
                            displayScaling: self._displayScaling,
                            cellSize: self._cellSize,
                            cellPadding: self._cellPadding,
                            cellShape: self._cellShape,
                            cellTransparency: Defaults.displayTransparency,
                            cellBleed: Defaults.cellBleed,
                            cellForeground: cellForeground,
                            cellBackground: self._cellBackground,
                            cellFactory: self._cellFactory)

        print_debug()

        // self.fill(with: self._cellBackground)
        // self._cells!.fill(Color.green)
        self._cells!.fill(self._cellBackground)

        func print_debug() {
            print("INIT-SCREEN-SCALE:      \(Screen.initialScale)")
            print("SCREEN-SCALE:           \(screen.scale)")
            print("SCREEN-SIZE:            \(self.scaled(screen.width)) x \(self.scaled(screen.height))")
            if (self._displayScaling) {
                print("SCREEN-SIZE-US:         \(screen.width) x \(screen.height)")
            }
            print("DISPLAY-SCALING:        \(self._displayScaling)")
            print("DISPLAY-SIZE:           \(self._displayWidth) x \(self._displayHeight)")
            if (self._displayScaling) {
                print("DISPLAY-SIZE-US:        \(self._displayWidthUnscaled) x \(self._displayHeightUnscaled)")
            }
            print("CELL-COLS:              \(self._cells!.ncolumns)")
            print("CELL-ROWS:              \(self._cells!.nrows)")
            print("CELL-SIZE:              \(self._cellSize)")
            if (self._displayScaling) {
                print("CELL-SIZE-US:           \(self._cellSizeUnscaled)")
            }
            print("CELL-PADDING:           \(self._cellPadding)")
            print("CELL-PADDING-US:        \(self.unscaled(self._cellPadding))")
        }

        func print_debug(_ neatCells: [Cells.PreferredSize], _ neatCell: Cells.PreferredSize, verbose: Bool = false) {
            if (verbose) {
                for neatCell in neatCells {
                    print("NEAT-CELL-US> CELL-SIZE \(neatCell.cellSize)" +
                          " | DISPLAY: \(neatCell.displayWidth) x \(neatCell.displayHeight)" +
                          (self._displayScaling ?
                          " | DISPLAY-US: \(self.unscaled(neatCell.displayWidth)) x \(self.unscaled(neatCell.displayHeight))" : "") +
                          " | MARGINS: [\(self._displayWidth - self.scaled(neatCell.displayWidth))" +
                          ",\(self._displayHeight - self.scaled(neatCell.displayHeight))]" +
                          (self._displayScaling ?
                          " | MARGINS-US: [\(self._displayWidthUnscaled - neatCell.displayWidth)" +
                          ",\(self._displayHeightUnscaled - neatCell.displayHeight)]" : ""))
                }
            }
            print("INIT-DISPLAY-SIZE:         \(self._displayWidth) x \(self._displayHeight)")
            if (self._displayScaling) {
                print("INIT-DISPLAY-SIZE-US:      \(self._displayWidthUnscaled) x \(self._displayHeightUnscaled)")
            }
            print("INIT-CELL-SIZE:            \(self._cellSize)")
            if (self._displayScaling) {
                print("INIT-CELL-SIZE-US:         \(self._cellSizeUnscaled)")
            }
            print("NEAT-DISPLAY-SIZE:         \(self.scaled(neatCell.displayWidth)) x \(self.scaled(neatCell.displayHeight))")
            if (self._displayScaling) {
                print("NEAT-DISPLAY-SIZE-US:      \(neatCell.displayWidth) x \(neatCell.displayHeight)")
            }
            print("NEAT-CELL-SIZE:            \(self.scaled(neatCell.cellSize))")
            if (self._displayScaling) {
                print("NEAT-CELL-SIZE-US:         \(neatCell.cellSize)")
            }
        }
    }

    public var displayScale: CGFloat {
        self._displayScaling ? self._displayScale : 1
    }

    public var displayWidthUnscaled: Int {
        self._displayWidthUnscaled
    }

    public var displayHeightUnscaled: Int {
        self._displayHeightUnscaled
    }

    internal func scaled(_ value: Int) -> Int {
        return self._displayScaling ? Int(round(CGFloat(value) * self._displayScale)) : value
    }

    internal func unscaled(_ value: Int) -> Int {
        self._displayScaling ? Int(round(CGFloat(value) / self._displayScale)) : value
    }

    public var cellSize: Int {
        self._cellSize
    }

    public var cellPadding: Int {
        self._cellPadding
    }

    public var cellShape: CellShape {
        self._cellShape
    }

    public var cellColorMode: CellColorMode {
        self._cellColorMode
    }

    public var background: CellColor {
        self._cellBackground
    }

    public func normalizedLocation(screenPoint: CGPoint,
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
                x = CGFloat(self._displayWidthUnscaled) - 1 - (screenPoint.x - gridOrigin.x)
                y = CGFloat(self._displayHeightUnscaled) - 1 - (screenPoint.y - gridOrigin.y)
            }
            else if (orientation.previous.isLandscape) {
                x = screenPoint.y - gridOrigin.x
                y = CGFloat(self._displayHeightUnscaled) - 1 - (screenPoint.x - gridOrigin.y)
            }
            else {
                x = screenPoint.x - gridOrigin.x
                y = screenPoint.y - gridOrigin.y
            }
        case .landscapeRight:
            x = screenPoint.y - gridOrigin.x
            y = CGFloat(self._displayHeightUnscaled) - 1 - (screenPoint.x - gridOrigin.y)
        case .landscapeLeft:
            x = CGFloat(self._displayWidthUnscaled) - 1 - (screenPoint.y - gridOrigin.x)
            y = screenPoint.x - gridOrigin.y
        default:
            x = screenPoint.x - gridOrigin.x
            y = screenPoint.y - gridOrigin.y
        }
        return CGPoint(x: x, y: y)
    }

    var _dragPoint: CGPoint?

    public func onDrag(_ location: CGPoint) {
        /*
        if let cell = self._cells?.cell(location) {
            if ((self._dragCell == nil) || (self._dragCell!.location != cell.location)) {
                let color = cell.foreground.tintedRed(by: 0.60)
                cell.write(foreground: color, background: self.background, limit: true)
                self._dragCell = cell
            }
        }
        */
        /*
        if let cell: LifeCell = self._cells?.cell(location) {
            if ((self._dragCell == nil) || (self._dragCell!.location != cell.location)) {
                cell.toggle()
                self._dragCell = cell
            }
        }
        */
            let x = location.x
            let y = location.y
            let gp = self._cells!.locate(location)
            let gx = (gp != nil) ? gp!.x : -1
            let gy = (gp != nil) ? gp!.y : -1
            let c = self._cells!.cell(location)
            let cx = (c != nil) ? c!.x : -1
            let cy = (c != nil) ? c!.y : -1
            print("DRAG: [\(String(format: "%.1f", x)),\(String(format: "%.1f", y))] -> [\(gx),\(gy)] -> (\(cx),\(cy)]")

        var shiftx: Int = 0
        var shifty: Int = 0
        if (self._dragPoint == nil) {
            self._dragPoint = location
        }
        else {
            shiftx = Int(location.x) - Int(self._dragPoint!.x)
            shifty = Int(location.y) - Int(self._dragPoint!.y)
            // self._dragPoint = location
            print("SHIFT: \(shiftx) \(shifty)")
        }
        if let cell: LifeCell = self._cells?.cell(location) {

        /* self._cells = Cells(displayWidth: self._displayWidth,
                            displayHeight: self._displayHeight,
                            displayScale: self._displayScale,
                            displayScaling: self._displayScaling,
                            cellSize: self._cellSize / 4,
                            cellPadding: self._cellPadding,
                            cellShape: self._cellShape,
                            cellTransparency: Defaults.displayTransparency,
                            cellBleed: Defaults.cellBleed,
                            cellForeground: CellColor.white,
                            cellBackground: self._cellBackground,
                            cellFactory: self._cellFactory) */

            if ((self._dragCell == nil) || (self._dragCell!.location != cell.location)) {
                let start = Date()
                self._cells!.fill(self._cellBackground)
                for cell in self._cells!.cells {
                    self._cells!.writeCell(x: cell.x, y: cell.y,
                                           shiftx: shiftx, shifty: shifty,
                                           foreground: cell.foreground, background: cell.background,
                                           limit: false)
                }
                print(String(format: "DRAW-TIME: %.5fs", Date().timeIntervalSince(start)))
            }
        }
    }

    public func onDragEnd(_ location: CGPoint) {
        self._dragPoint = nil
        /*
        if let cell = self._cells?.cell(location) {
            self._dragCell = nil
            let color = CellColor.random()
            cell.write(foreground: color, background: self.background, limit: true)
        }
        */
        self.onDrag(location)
        self._dragCell = nil
    }

    public func onTap(_ location: CGPoint) {
        /*
        if let _ = self._cells?.cell(location) {
            self.randomize()
        }
        */
        if let cell: LifeCell = self._cells?.cell(location) {
            cell.toggle()
        }
    }

    public func locate(_ location: CGPoint) -> CellGridPoint? {
        return self._cells?.locate(location)
    }

    func fill(with color: CellColor, limit: Bool = true) {
        if let cells = self._cells {
            for cell in cells.cells {
                cell.write(foreground: color, background: self._cellBackground, limit: limit)
            }
        }
    }

    func testingLifeSetup() {
/*
        var cells: [Cell] = []
        let ncolumns = 12 /// 100
        let nrows = 21 /// 20 /// 100
        for y in 0..<nrows {
            for x in 0..<ncolumns {
                var fg: CellColor
                if ((x == 0) /* && (y == 0) */ ) {
                    fg = CellColor(Color.blue)
                }
                else if ((x == 1) /* && (y == 0) */ ) {
                    fg = CellColor(Color.purple)
                }
                else if ((x == 8) /* && (y == 0) */ ) {
                    fg = CellColor(Color.green)
                }
                else if ((x == 9) /* && (y == 0) */ ) {
                    fg = CellColor(Color.red)
                }
                else if ((x == 10) /* && (y == 0) */ ) {
                    fg = CellColor(Color.yellow)
                }
                else if ((x == 11) /* && (y == 0) */ ) {
                    fg = CellColor(Color.orange)
                }
                else {
                    fg = CellColor.white
                }
                var cell = LifeCell(parent: self._cells!, x: x, y: y,
                                    foreground: fg, background: self._cellBackground,
                                    activeColor: CellColor(Color.red), inactiveColor: CellColor(Color.gray))
                cells.append(cell)
            }
        }
        // self._cells!.setView(cells: cells, ncolumns: ncolumns, nrows: nrows, x: 0, y: 0, shiftx: -60, shifty: 0)
        self._cells!.setView(cells: cells, ncolumns: ncolumns, nrows: nrows, x: 0, y: 0, shiftx: 0, shifty: 0)
*/
        if let cells = self._cells {
            for case let cell as LifeCell in cells.cells {
                cell.deactivate()
                if ((cell.x == 0) && (cell.y == 0)) {
                    cell.write(foreground: CellColor(Color.blue))
                }
                else if ((cell.x == cells.ncolumns - 1) && (cell.y == cells.nrows - 1)) {
                    cell.write(foreground: CellColor(Color.green))
                }
                else {
                    cell.write()
                }
            }
        }
    }

    func testingLife() {
        if let cells = self._cells {
            cells.nextGeneration()
        }
    }

    func randomize() {
        CellGrid._randomize(displayWidth: self._displayWidth,
                            displayHeight: self._displayHeight,
                            cellSize: self.cellSize,
                            cellColorMode: self.cellColorMode,
                            cellShape: self.cellShape,
                            cellPadding: self.cellPadding,
                            cellLimitUpdate: self._cellLimitUpdate,
                            background: self.background,
                            cells: self._cells!)
    }

    static func _randomize(displayWidth: Int,
                           displayHeight: Int,
                           cellSize: Int,
                           cellColorMode: CellColorMode,
                           cellShape: CellShape,
                           cellPadding: Int,
                           cellLimitUpdate: Bool,
                           background: CellColor,
                           cells: Cells)
    {
        let start = Date()
        for cell in cells.cells {
            cell.write(foreground: CellColor.random(), background: background, limit: cellLimitUpdate)
        }
        let end = Date()
        let elapsed = end.timeIntervalSince(start)
        print(String(format: "CACHED-RANDOMIZE-TIME: %.5f sec | \(cellLimitUpdate)", elapsed))
    }

    func writeCell(_ cell: Cell, _ color: CellColor, limit: Bool = true) {
        cell.write(foreground: color, background: self.background, limit: limit)
    }

    public var image: CGImage? {
        self._cells?.image
    }
}
