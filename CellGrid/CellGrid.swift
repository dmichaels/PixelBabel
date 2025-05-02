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
        public static let displayTransparency: UInt8 = 255
        public static let cellSize: Int = 43 // 18 // 43 // 32 // 8 // 83 // 43 // 37 // 35
        public static let cellSizeNeat: Bool = true
        public static let cellPadding: Int = 1 // 1
        public static let cellBleed: Bool = false
        public static let cellShape: CellShape = CellShape.rounded // CellShape.square // CellShape.rounded
        public static let cellColorMode: CellColorMode = CellColorMode.color
        public static let cellForeground: CellColor = CellColor.black
        public static let cellBackground: CellColor = CellColor(40, 40, 40)
        public static let cellAntialiasFade: Float = 0.6
        public static let cellRoundedRectangleRadius: Float = 0.25
        public static var cellPreferredSizeMarginMax: Int = 30
        public static let cellLimitUpdate: Bool = true
        public static let colorSpace = CGColorSpaceCreateDeviceRGB()
        public static let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
/*
        public static let bitmapInfo: UInt32 = CFByteOrderGetCurrent() == CFByteOrderBigEndian.rawValue ?
                                               CGBitmapInfo.byteOrder32Big.union(.premultipliedLast).rawValue :
                                               CGBitmapInfo.byteOrder32Little.union(.premultipliedFirst).rawValue
        public static let alphaInfo = CGImageAlphaInfo.premultipliedFirst
        public static let byteOrder = CFByteOrderGetCurrent() == CFByteOrderBigEndian.rawValue ?
                                      CGBitmapInfo.byteOrder32Big :
                                      CGBitmapInfo.byteOrder32Little
        public static let bitmapInfo = CellGrid.Defaults.byteOrder.union(CGBitmapInfo(rawValue:
                                           CellGrid.Defaults.alphaInfo.rawValue)).rawValue
*/
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
        print("PIXELMAP-CONSTRUCTOR!!!")
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

        func scaled(_ value: Int) -> Int {
            displayScaling ? Int(round(CGFloat(value) * displayScale)) : value
        }

        func unscaled(_ value: Int) -> Int {
            displayScaling ? Int(round(CGFloat(value) / displayScale)) : value
        }

        print("PIXELMAP-CONFIGURE!!!")
        self._displayScale = screen.scale
        self._displayScaling = [CellShape.square, CellShape.inset].contains(cellShape) ? false : displayScaling
        self._displayWidth = scaled(displayWidth)
        self._displayHeight = scaled(displayHeight)
        self._displayWidthUnscaled = displayWidth
        self._displayHeightUnscaled = displayHeight

        self._cellSize = scaled(cellSize)
        self._cellSizeUnscaled = cellSize
        self._cellPadding = scaled(cellPadding)
        self._cellBleed = cellBleed
        self._cellShape = cellShape
        self._cellColorMode = cellColorMode
        self._cellBackground = cellBackground

        let neatCells = Cells.preferredCellSizes(self._displayWidthUnscaled, self._displayHeightUnscaled, cellPreferredSizeMarginMax: self._cellPreferredSizeMarginMax)
        /* for neatCell in neatCells {
            print("NEAT-CELL-US: \(neatCell.cellSize) | \(neatCell.displayWidth) \(neatCell.displayHeight) | \(self._displayWidthUnscaled - neatCell.displayWidth) \(self._displayHeightUnscaled - neatCell.displayHeight)")
        } */
        if (cellSizeNeat) {
            print("INITIAL-DISPLAY-SIZE:           \(self._displayWidth) x \(self._displayHeight)")
            print("INITIAL-DISPLAY-SIZE-US:        \(self._displayWidthUnscaled) x \(self._displayHeightUnscaled)")
            if let neatCell = Cells.closestPreferredCellSize(in: neatCells, to: self._cellSizeUnscaled) {
                print("ORIG-CELL-SIZE:            \(scaled(cellSize))")
                print("ORIG-CELL-SIZE-US:         \(cellSize)")
                print("NEAT-CELL-SIZE:            \(scaled(neatCell.cellSize))")
                print("NEAT-CELL-SIZE-US:         \(neatCell.cellSize)")
                print("NEAT-DISPLAY-SIZE:         \(scaled(neatCell.displayWidth)) x \(scaled(neatCell.displayHeight))")
                print("NEAT-DISPLAY-SIZE-US:      \(neatCell.displayWidth) x \(neatCell.displayHeight)")
                print("NEAT-DISPLAY-MARGIN-XY:    \(self._displayWidth - scaled(neatCell.displayWidth)) , \(self._displayHeight - scaled(neatCell.displayHeight))")
                print("NEAT-DISPLAY-MARGIN-XY-US: \(self._displayWidthUnscaled - neatCell.displayWidth) , \(self._displayHeightUnscaled - neatCell.displayHeight)")
                self._cellSize = scaled(neatCell.cellSize)
                self._displayWidth = scaled(neatCell.displayWidth)
                self._displayHeight = scaled(neatCell.displayHeight)
                self._displayWidthUnscaled = neatCell.displayWidth
                self._displayHeightUnscaled = neatCell.displayHeight
            }
        }

        self._cells = Cells(displayWidth: self._displayWidth,
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

        print("SCREEN-SCALE-INITIAL:   \(Screen.initialScale)")
        print("SCREEN-SCALE:           \(screen.scale)")
        print("SCREEN-SIZE:            \(scaled(screen.width)) x \(scaled(screen.height))")
        print("SCREEN-SIZE-US:         \(screen.width) x \(screen.height)")
        print("DISPLAY-SCALING:        \(self._displayScaling)")
        print("DISPLAY-SIZE:           \(self._displayWidth) x \(self._displayHeight)")
        print("DISPLAY-SIZE-US:        \(self._displayWidthUnscaled) x \(self._displayHeightUnscaled)")
        print("CELL-COLS:              \(self._cells!.ncolumns)")
        print("CELL-ROWS:              \(self._cells!.nrows)")
        print("CELL-SIZE:              \(self.cellSize)")
        print("CELL-SIZE-US:           \(self._cellSizeUnscaled)")
        print("CELL-PADDING:           \(self.cellPadding)")
        print("CELL-PADDING-US:        \(unscaled(self.cellPadding))")

        // self.fill(with: self._cellBackground)
        // self._cells!.fill(Color.green)
        self._cells!.fill(self._cellBackground)
    }

    public var displayWidthUnscaled: Int {
        self._displayWidthUnscaled
    }

    public var displayHeightUnscaled: Int {
        self._displayHeightUnscaled
    }

    public var displayScale: CGFloat {
        self._displayScaling ? self._displayScale : 1
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

    var _dragStart: CGPoint?

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
        if (self._dragStart == nil) {
            self._dragStart = location
        }
        else {
            shiftx = Int(location.x) - Int(self._dragStart!.x)
            shifty = Int(location.y) - Int(self._dragStart!.y)
            print("SHIFT: \(shiftx) \(shifty)")
        }
        if let cell: LifeCell = self._cells?.cell(location) {
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
        self._dragStart = nil
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
