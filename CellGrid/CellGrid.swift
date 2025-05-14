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
        public static let cellSize: Int = 43 // 51
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
    private var _cellShape: CellShape = Defaults.cellShape
    private var _cellColorMode: CellColorMode = Defaults.cellColorMode
    private var _cellBackground: CellColor = Defaults.cellBackground
    private var _cellAntialiasFade: Float = Defaults.cellAntialiasFade
    private var _cellRoundedRectangleRadius: Float = Defaults.cellRoundedRectangleRadius
    private var _cellPreferredSizeMarginMax: Int = Defaults.cellPreferredSizeMarginMax
    private var _cellLimitUpdate: Bool = Defaults.cellLimitUpdate
    private var _gridColumns: Int = 12
    private var _gridRows: Int = 21
    private var _cells: CellGridView? = nil
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
        self._displayWidthUnscaled = displayWidth
        self._displayHeightUnscaled = displayHeight

        self._cellSize = self.scaled(cellSize)
        self._cellSizeUnscaled = cellSize
        self._cellPadding = self.scaled(cellPadding)
        self._cellShape = cellShape
        self._cellColorMode = cellColorMode
        self._cellBackground = cellBackground

        let neatCells = CellGridView.preferredCellSizes(self._displayWidthUnscaled, self._displayHeightUnscaled,
                                                        cellPreferredSizeMarginMax: self._cellPreferredSizeMarginMax)
        if (cellSizeNeat) {
            if let neatCell = CellGridView.closestPreferredCellSize(in: neatCells, to: self._cellSizeUnscaled) {
                print_debug(neatCells, neatCell, verbose: true)
                self._cellSize = self.scaled(neatCell.cellSize)
                self._displayWidth = self.scaled(neatCell.displayWidth)
                self._displayHeight = self.scaled(neatCell.displayHeight)
                self._displayWidthUnscaled = neatCell.displayWidth
                self._displayHeightUnscaled = neatCell.displayHeight
            }
        }

        self._cells = CellGridView(viewParent: self,
                                   viewWidth: self._displayWidth,
                                   viewHeight: self._displayHeight,
                                   viewBackground: self._cellBackground,
                                   viewTransparency: Defaults.displayTransparency,
                                   gridColumns: self._gridColumns,
                                   gridRows: self._gridRows,
                                   cellSize: self._cellSize,
                                   cellPadding: self._cellPadding,
                                   cellShape: self._cellShape,
                                   cellFactory: self._cellFactory)

        if let cells = self._cells {
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

        print_debug()

        func print_debug() {
            print("INIT-SCREEN-SCALE:      \(Screen.initialScale)")
            print("SCREEN-SCALE:           \(screen.scale)")
            print("SCREEN-SIZE:            \(self.scaled(screen.width)) x \(self.scaled(screen.height))")
            if (self._displayScaling) {
                print("SCREEN-SIZE-US:     \(screen.width) x \(screen.height)")
            }
            print("DISPLAY-SCALING:        \(self._displayScaling)")
            print("DISPLAY-SIZE:           \(self._displayWidth) x \(self._displayHeight)")
            if (self._displayScaling) {
                print("DISPLAY-SIZE-US:    \(self._displayWidthUnscaled) x \(self._displayHeightUnscaled)")
            }
            print("CELL-SIZE:              \(self._cellSize)")
            if (self._displayScaling) {
                print("CELL-SIZE-US:       \(self._cellSizeUnscaled)")
            }
            print("CELL-PADDING:           \(self._cellPadding)")
            print("CELL-PADDING-US:        \(self.unscaled(self._cellPadding))")
        }

        func print_debug(_ neatCells: [CellGridView.PreferredSize], _ neatCell: CellGridView.PreferredSize, verbose: Bool = false) {
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

    public func onDrag(_ location: CGPoint) {
        if let cells = self._cells {
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
        if let cells = self._cells {
            if let cell: LifeCell = cells.gridCell(location) {
                if cell.x == 0 && cell.y == 0 {
                    let incrementCellSize = 8
                    self._cellSize += self.scaled(incrementCellSize)
                    self._cells = CellGridView(viewParent: self,
                                               viewWidth: self._displayWidth,
                                               viewHeight: self._displayHeight,
                                               // viewWidth: 400, // for 51
                                               // viewHeight: 850, // for 51
                                               viewBackground: self._cellBackground,
                                               viewTransparency: Defaults.displayTransparency,
                                               gridColumns: self._gridColumns,
                                               gridRows: self._gridRows,
                                               cellSize: self._cellSize,
                                               cellPadding: self._cellPadding,
                                               cellShape: self._cellShape,
                                               cellFactory: self._cellFactory)
                                               // cells: self._cells!._cells,
                                               // buffer: self._cells!._buffer)
                    self._cells!.shift(shiftx: 0, shifty: 0)
                }
                else {
                    cell.toggle()
                    cell.write()
                }
            }
        }
    }

    public func locate(_ screenPoint: CGPoint) -> CellLocation? {
        if let cells = self._cells {
            return cells.gridCellLocation(screenPoint)
        }
        return nil
    }

    func testingLife() {
        if let cells = self._cells {
            cells.nextGeneration()
        }
    }

/*
    func randomize() {
        if let cells = self._cells {
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
        self._cells?.image
    }
}
