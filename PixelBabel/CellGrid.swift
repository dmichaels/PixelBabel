import CoreGraphics
import Foundation
import SwiftUI
import Utils

@MainActor
class CellGrid: ObservableObject {

    struct Defaults {
        public static let displayWidth: Int = ScreenInfo.initialWidth
        public static let displayHeight: Int = ScreenInfo.initialHeight
        public static let displayScale: CGFloat = ScreenInfo.initialScale
        public static let displayScaling: Bool = true
        public static let displayTransparency: UInt8 = 255
        public static let cellSize: Int = 43 // 32 // 8 // 83 // 43 // 37 // 35
        public static let cellSizeNeat: Bool = true
        public static let cellPadding: Int = 2
        public static let cellBleeds: Bool = false
        public static let cellShape: CellShape = CellShape.rounded // CellShape.rounded
        public static let cellColorMode: CellColorMode = CellColorMode.color
        public static let cellBackground: CellColor = CellColor.dark
        public static let cellAntialiasFade: Float = 0.6
        public static let cellRoundedRectangleRadius: Float = 0.25
        public static var cellPreferredSizeMarginMax: Int   = 30
        public static let cellLimitUpdate: Bool = true
        public static let colorSpace = CGColorSpaceCreateDeviceRGB()
        public static let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
    }

    private var _displayWidth: Int = ScreenInfo.initialWidth
    private var _displayHeight: Int = ScreenInfo.initialHeight
    private var _displayScale: CGFloat = ScreenInfo.initialScale
    private var _displayScaling: Bool = Defaults.displayScaling
    private var _cellSize: Int = Defaults.cellSize
    private var _cellPadding: Int = Defaults.cellPadding
    private var _cellBleeds: Bool = Defaults.cellBleeds
    private var _cellShape: CellShape = Defaults.cellShape
    private var _cellColorMode: CellColorMode = Defaults.cellColorMode
    private var _cellBackground: CellColor = Defaults.cellBackground
    private var _cellAntialiasFade: Float = Defaults.cellAntialiasFade
    private var _cellRoundedRectangleRadius: Float = Defaults.cellRoundedRectangleRadius
    private var _cellPreferredSizeMarginMax: Int = Defaults.cellPreferredSizeMarginMax
    private var _cellLimitUpdate: Bool = Defaults.cellLimitUpdate
    private var _cells: Cells? = nil
    private var _cellFactory: Cells.CellFactory?
    private var _dragCell: Cell? = nil

    init(cellFactory: Cells.CellFactory? = nil) {
        self._cellFactory = cellFactory
        print("PIXELMAP-CONSTRUCTOR!!!")
    }

    func configure(screen: ScreenInfo,
                   displayWidth: Int = Defaults.displayWidth,
                   displayHeight: Int = Defaults.displayHeight,
                   cellSize: Int = Defaults.cellSize,
                   cellSizeNeat: Bool = Defaults.cellSizeNeat,
                   cellPadding: Int = Defaults.cellPadding,
                   cellBleeds: Bool = Defaults.cellBleeds,
                   cellShape: CellShape = Defaults.cellShape,
                   cellColorMode: CellColorMode = Defaults.cellColorMode,
                   cellBackground: CellColor = Defaults.cellBackground,
                   displayScaling: Bool = Defaults.displayScaling)
    {
        print("PIXELMAP-CONFIGURE!!!")
        self._displayScale = screen.scale
        self._displayScaling = [CellShape.square, CellShape.inset].contains(cellShape) ? false : displayScaling
        self._displayWidth = scaled(displayWidth)
        self._displayHeight = scaled(displayHeight)

        self._cellSize = scaled(cellSize)
        self._cellPadding = scaled(cellPadding)
        self._cellBleeds = cellBleeds
        self._cellShape = cellShape
        self._cellColorMode = cellColorMode
        self._cellBackground = cellBackground

        let neatCells = Cells.preferredCellSizes(unscaled(self._displayWidth), unscaled(self._displayHeight), cellPreferredSizeMarginMax: self._cellPreferredSizeMarginMax)
        // print("NEAT-CELL-SIZES-US:")
        // for neatCell in neatCells {
        //     print("NEAT-CELL-US: \(neatCell.cellSize) | \(neatCell.displayWidth) \(neatCell.displayHeight) | \(unscaled(self._displayWidth) - neatCell.displayWidth) \(unscaled(self._displayHeight) - neatCell.displayHeight)")
        // }
        if (cellSizeNeat) {
            if let neatCell = Cells.closestPreferredCellSize(in: neatCells, to: unscaled(self._cellSize)) {
                print("ORIG-CELL-SIZE:            \(scaled(cellSize))")
                print("ORIG-CELL-SIZE-US:         \(cellSize)")
                print("NEAT-CELL-SIZE:            \(scaled(neatCell.cellSize))")
                print("NEAT-CELL-SIZE-US:         \(neatCell.cellSize)")
                print("NEAT-DISPLAY-SIZE:         \(scaled(neatCell.displayWidth)) x \(scaled(neatCell.displayHeight))")
                print("NEAT-DISPLAY-SIZE-US:      \(neatCell.displayWidth) x \(neatCell.displayHeight)")
                print("NEAT-DISPLAY-MARGIN-XY:    \(self._displayWidth - scaled(neatCell.displayWidth)) , \(self._displayHeight - scaled(neatCell.displayHeight))")
                print("NEAT-DISPLAY-MARGIN-XY-US: \(unscaled(self._displayWidth) - neatCell.displayWidth) , \(unscaled(self._displayHeight) - neatCell.displayHeight)")
                self._cellSize = scaled(neatCell.cellSize)
                self._displayWidth = scaled(neatCell.displayWidth)
                self._displayHeight = scaled(neatCell.displayHeight)
            }
            else {
                print("xyzzy.no-neat-cell")
            }
        }

        print("SCREEN-SCALE-INITIAL:   \(ScreenInfo.initialScale)")
        print("SCREEN-SCALE:           \(screen.scale)")
        print("SCREEN-SIZE:            \(scaled(screen.width)) x \(scaled(screen.height))")
        print("SCREEN-SIZE-US:         \(screen.width) x \(screen.height)")
        print("DISPLAY-SCALING:        \(self._displayScaling)")
        print("DISPLAY-SIZE:           \(self._displayWidth) x \(self._displayHeight)")
        print("DISPLAY-SIZE-US:        \(unscaled(self._displayWidth)) x \(unscaled(self._displayHeight))")
        print("CELL-MAP-SIZE:          \(self.width) x \(self.height)")
        print("CELL-SIZE:              \(self.cellSize)")
        print("CELL-SIZE-US:           \(unscaled(self._cellSize))")
        print("CELL-PADDING:           \(self.cellPadding)")
        print("CELL-PADDING-US:        \(unscaled(self.cellPadding))")

        self._cells = self._configureCells()

        // self.fill(with: self._cellBackground)
    }

    private func _configureCells() -> Cells {
        let cells = Cells(displayWidth: self._displayWidth,
                          displayHeight: self._displayHeight,
                          displayScale: self._displayScale,
                          displayScaling: self._displayScaling,
                          cellSize: self._cellSize,
                          cellPadding: self._cellPadding,
                          cellShape: self._cellShape,
                          cellTransparency: Defaults.displayTransparency,
                          cellFactory: self._cellFactory)
        for y in 0..<self.height {
            for x in 0..<self.width {
                cells.defineCell(x: x, y: y)
            }
        }
        return cells
    }

    public var displayWidth: Int {
        self._displayWidth
    }

    public var displayHeight: Int {
        self._displayHeight
    }

    public var displayWidthUnscaled: Int {
        unscaled(self._displayWidth)
    }

    public var displayHeightUnscaled: Int {
        unscaled(self._displayHeight)
    }

    public var displayScale: CGFloat {
        self._displayScaling ? self._displayScale : 1
    }

    private func scaled(_ value: Int) -> Int {
        self._displayScaling ? Int(round(CGFloat(value) * self.displayScale)) : value
    }

    public func unscaled(_ value: Int) -> Int {
        self._displayScaling ? Int(round(CGFloat(value) / self.displayScale)) : value
    }

    // Returns the logical width of this PixelMap, i.e. the number of
    // cell-size-sized cells that can fit across the width of the display.
    //
    public var width: Int {
        self._cellBleeds ? ((self._displayWidth + self._cellSize - 1) / self._cellSize)
                         : (self._displayWidth / self._cellSize)
    }

    // Returns the logical height of this PixelMap, i.e. the number of
    // cell-size-sized cells that can fit down the height of the display.
    //
    public var height: Int {
        self._cellBleeds ? ((self._displayHeight + self._cellSize - 1) / self._cellSize)
                         : (self._displayHeight / self._cellSize)
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

    public func onDrag(_ location: CGPoint) {
        if let cell = self._cells?.cell(location) {
            if ((self._dragCell == nil) || (self._dragCell!.location != cell.location)) {
                let color = cell.foreground.tintedRed(by: 0.60)
                cell.write(foreground: color, background: self.background, limit: true)
                self._dragCell = cell
            }
        }
    }

    public func onDragEnd(_ location: CGPoint) {
        if let cell = self._cells?.cell(location) {
            self._dragCell = nil
            let color = CellColor.random()
            cell.write(foreground: color, background: self.background, limit: true)
        }
    }

    public func onTap(_ location: CGPoint) {
        if let _ = self._cells?.cell(location) {
            self.randomize()
        }
    }

    public func locate(_ location: CGPoint) -> CellGridPoint? {
        return self._cells?.locate(location)
    }

    func fill(with color: CellColor, limit: Bool = true) {
        if let cells = self._cells {
            for cell in cells.cells {
                cell.write(foreground: color, background: self._cellBackground, limit: limit) // xyzzy
            }
        }
    }

    func randomize() {
        CellGrid._randomize(displayWidth: self._displayWidth,
                            displayHeight: self._displayHeight,
                            width: self.width, height: self.height,
                            cellSize: self.cellSize,
                            cellColorMode: self.cellColorMode,
                            cellShape: self.cellShape,
                            cellPadding: self.cellPadding,
                            cellLimitUpdate: self._cellLimitUpdate,
                            background: self.background,
                            cells: self._cells)
    }

    static func _randomize(displayWidth: Int,
                           displayHeight: Int,
                           width: Int, height: Int,
                           cellSize: Int,
                           cellColorMode: CellColorMode,
                           cellShape: CellShape,
                           cellPadding: Int,
                           cellLimitUpdate: Bool,
                           background: CellColor,
                           cells: Cells? = nil)
    {
        let start = Date()

        if (cells != nil) {
            for cell in cells!.cells {
                cell.write(foreground: CellColor.random(), background: background, limit: cellLimitUpdate) // xyzzyxyzzy
            }
            let end = Date()
            let elapsed = end.timeIntervalSince(start)
            print(String(format: "CACHED-RANDOMIZE-TIME: %.5f sec | \(cellLimitUpdate)", elapsed))
            return
        }
    }

    func writeCell(_ cell: Cell, _ color: CellColor, limit: Bool = true) {
        cell.write(foreground: color, background: self.background, limit: limit) // xyzzy
    }

    public var image: CGImage? {
        self._cells?.image
    }
}
