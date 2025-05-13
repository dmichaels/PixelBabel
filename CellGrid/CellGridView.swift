import Foundation
import SwiftUI
import Utils

// A main purpose of this (as first created) is for keeping track of the backing pixel buffer
// indices for the (canonical) cell; for the purpose of being able to write the values very fast
// using block memory copy (Memory.fastcopy). It is ASSUMED that the abufferBlocksddBufferItem function
// is called with indices which are monotonically increasing, and are not duplicated or out of order
// or anything weird; assume called from the buffer setting loop in the PixelMap._write method.

class DEBUG {
}

@MainActor
class CellGridView {

    private let _viewParent: CellGrid
    private let _viewWidth: Int
    private let _viewHeight: Int
    private let _viewWidthUnscaled: Int
    private let _viewHeightUnscaled: Int
    private let _viewWidthExtra: Int
    private let _viewHeightExtra: Int
    private let _viewColumns: Int
    private let _viewRows: Int
    private let _viewCellEndX: Int
    private let _viewCellEndY: Int
    private let _viewBackground: CellColor
    private let _viewTransparency: UInt8

    private let _gridColumns: Int
    private let _gridRows: Int
    private let _gridCellEndX: Int
    private let _gridCellEndY: Int

    private let _cellSize: Int
    private let _cellSizeUnscaled: Int
    private let _cellPadding: Int
    private let _cellShape: CellShape
    private let _cellFactory: CellFactory?
    internal var _cells: [Cell] // TODO/xyzzy private
    internal var _buffer: [UInt8] // TODO/xyzzy private
    private let _bufferBlocks: CellGridView.BufferBlocks

    // These change based on moving/shifting the cell-grid around the grid-view.
    //
    private var _shiftCellX: Int
    private var _shiftCellY: Int
    private var _shiftX: Int
    private var _shiftY: Int
    private var _viewColumnsExtra: Int
    private var _viewRowsExtra: Int

    init(viewParent: CellGrid,
         viewWidth: Int,
         viewHeight: Int,
         viewBackground: CellColor,
         viewTransparency: UInt8 = 255,
         gridColumns: Int,
         gridRows: Int,
         cellSize: Int,
         cellPadding: Int,
         cellShape: CellShape,
         cellFactory: CellFactory? = nil,
         cells: [Cell]? = nil,
         buffer: [UInt8]? = nil)
    {
        self._viewParent = viewParent
        self._viewWidth = viewWidth
        self._viewHeight = viewHeight
        self._viewWidthUnscaled = viewParent.unscaled(self._viewWidth)
        self._viewHeightUnscaled = viewParent.unscaled(self._viewHeight)

        self._cellSize = (cellSize > 0) ? cellSize : CellGrid.Defaults.cellSize
        self._cellSizeUnscaled = viewParent.unscaled(self._cellSize)
        self._cellPadding = (cellPadding > 0) ? cellPadding : CellGrid.Defaults.cellPadding
        self._cellShape = cellShape

        self._viewColumns = self._viewWidth / self._cellSize
        self._viewRows = self._viewHeight / self._cellSize
        self._viewCellEndX = self._viewColumns - 1
        self._viewCellEndY = self._viewRows - 1
        self._viewWidthExtra = self._viewWidth % self._cellSize
        self._viewHeightExtra = self._viewHeight % self._cellSize
        self._viewBackground = viewBackground
        self._viewTransparency = viewTransparency

        self._gridColumns = gridColumns > 0 ? gridColumns : self._viewColumns
        self._gridRows = gridRows > 0 ? gridRows : self._viewRows
        self._gridCellEndX = self._gridColumns - 1
        self._gridCellEndY = self._gridRows - 1

        self._cellFactory = cellFactory
        self._cells = cells != nil ? cells! : []
        self._buffer = buffer != nil ? buffer! : Memory.allocate(self._viewWidth * self._viewHeight * Screen.depth)
        self._bufferBlocks = CellGridView.BufferBlocks.createBufferBlocks(bufferSize: self._buffer.count,
                                                             displayWidth: self._viewWidth,
                                                             displayHeight: self._viewHeight,
                                                             cellSize: self._cellSize,
                                                             cellPadding: self._cellPadding,
                                                             cellShape: self._cellShape,
                                                             cellTransparency: self._viewTransparency)
        self._shiftCellX = 0
        self._shiftCellY = 0
        self._shiftX = 0
        self._shiftY = 0
        self._viewColumnsExtra = (self._viewWidthExtra > 0) ? 1 : 0
        self._viewRowsExtra = (self._viewHeightExtra > 0) ? 1 : 0

        if (cells == nil) {
            for y in 0..<self._gridRows {
                for x in 0..<self._gridColumns {
                    self.defineCell(x: x, y: y, foreground: CellGrid.Defaults.cellForeground)
                }
            }
        }
    }

    public func shift(shiftx: Int = 0, shifty: Int = 0)
    {
        let debugStart = Date()

        // Normalize the given pixel level shift to cell and pixel level.

        var shiftX: Int = self._viewParent.scaled(shiftx), shiftCellX: Int
        var shiftY: Int = self._viewParent.scaled(shifty), shiftCellY: Int

        if (shiftX != 0) {
            shiftCellX = shiftX / self._cellSize
            if (shiftCellX != 0) {
                shiftX = shiftX % self._cellSize
            }
        }
        else {
            shiftCellX = 0
        }
        if (shiftY != 0) {
            shiftCellY = shiftY / self._cellSize
            if (shiftCellY != 0) {
                shiftY = shiftY % self._cellSize
            }
        }
        else {
            shiftCellY = 0
        }

        // Restrict the shift to min/max; support different rules:
        //
        // - Disallow the left-most cell of the cell-grid being right-shifted past the right-most
        //   position of the grid-view, and the right-most cell of the grid-view being left-shifted
        //   past the left-most position of the grid-view; similarly for the vertical.
        //
        // - TODO
        //   Disallow the left-most cell of the cell-grid being right-shifted past the left-most
        //   position of the grid-view, and the right-most cell of the cell-grid being left-shifted
        //   past the right-most position of the grid-view; similarly for the vertical.

        func restrictShift(shiftCellXY: inout Int, shiftXY: inout Int, viewCellEndXY: Int,
                           viewSizeExtra: Int, viewSize: Int, gridCellEndXY: Int) {
            if shiftCellXY >= viewCellEndXY {
                if viewSizeExtra > 0 {
                    let totalShift = (shiftCellXY * self._cellSize) + shiftXY
                    if (viewSize - totalShift) <= self._cellSize {
                        let adjusted = viewSize - self._cellSize
                        shiftCellXY = adjusted / self._cellSize
                        shiftXY = adjusted % self._cellSize
                    }
                } else {
                    shiftCellXY = viewCellEndXY
                    shiftXY = 0
                }
            } else if -shiftCellXY >= gridCellEndXY {
                shiftCellXY = -gridCellEndXY
                shiftXY = 0
            }
        }

        restrictShift(shiftCellXY: &shiftCellX,
                      shiftXY: &shiftX,
                      viewCellEndXY: self._viewCellEndX,
                      viewSizeExtra: self._viewWidthExtra,
                      viewSize: self._viewWidth,
                      gridCellEndXY: self._gridCellEndX)
        restrictShift(shiftCellXY: &shiftCellY,
                      shiftXY: &shiftY,
                      viewCellEndXY: self._viewCellEndY,
                      viewSizeExtra: self._viewHeightExtra,
                      viewSize: self._viewHeight,
                      gridCellEndXY: self._gridCellEndY)

        // Update the shift related values for the view.

        self._shiftCellX = shiftCellX
        self._shiftCellY = shiftCellY
        self._shiftX = shiftX
        self._shiftY = shiftY

        self._viewColumnsExtra = (self._shiftX != 0 ? 1 : 0)
        if (self._shiftX > 0) {
            if (self._viewWidthExtra > self._shiftX) {
                self._viewColumnsExtra += 1
            }
        }
        else if (self._shiftX < 0) {
            if (self._viewWidthExtra > (self._cellSize + self._shiftX)) {
                self._viewColumnsExtra += 1
            }
        }
        else if (self._viewWidthExtra > 0) {
            self._viewColumnsExtra += 1
        }
        self._viewRowsExtra = (self._shiftY != 0 ? 1 : 0)
        if (self._shiftY > 0) {
            if (self._viewHeightExtra > self._shiftY) {
                self._viewRowsExtra += 1
            }
        }
        else if (self._shiftY < 0) {
            if (self._viewHeightExtra > (self._cellSize + self._shiftY)) {
                self._viewRowsExtra += 1
            }
        }
        else if (self._viewHeightExtra > 0) {
            self._viewRowsExtra += 1
        }

        // Now actually write the cells to the view.

        for vy in 0...self._viewCellEndY + self._viewRowsExtra {
            for vx in 0...self._viewCellEndX + self._viewColumnsExtra {
                self.writeCell(viewCellX: vx, viewCellY: vy)
            }
        }

        print(String(format: "SHIFTT> %.5fs | cs: \(self._cellSize)", Date().timeIntervalSince(debugStart)))
    }

    private typealias WriteCellBlock = (_ block: CellGridView.BufferBlock, _ index: Int, _ count: Int) -> Void

    // Draws at the given grid view cell location (viewCellX, viewCellY), the grid cell currently corresponding
    // to that location, taking into account the current shiftCellX/Y and shiftX/Y values, i.e. the cell and
    // pixel level based shift values, negative meaning to shift the grid cell left or up, and positive
    // meaning to shift the grid cell right or down.
    //
    public func writeCell(viewCellX: Int, viewCellY: Int)
    {
        // This was all a lot tricker than you might expect (yes basic arithmetic).

        let viewCellFirstX: Bool = (viewCellX == 0)
        let viewCellLastX: Bool = (viewCellX == self._viewCellEndX + self._viewColumnsExtra)
        var truncateLeft: Int = 0
        var truncateRight: Int = 0

        // Get the left/right truncation amount.

        if (self._shiftX > 0) {
            if (viewCellFirstX) {
                truncateLeft = self._cellSize - self._shiftX
            }
            else if (viewCellLastX) {
                if (self._viewWidthExtra > 0) {
                    truncateRight = (self._cellSize - self._shiftX + self._viewWidthExtra) % self._cellSize
                }
                else {
                    truncateRight = self._cellSize - self._shiftX
                }
            }
        }
        else if (self._shiftX < 0) {
            if (viewCellFirstX) {
                truncateLeft = -self._shiftX
            }
            else if (viewCellLastX) {
                if (self._viewWidthExtra > 0) {
                    truncateRight = (self._viewWidthExtra - self._shiftX) % self._cellSize
                }
                else {
                    truncateRight = -self._shiftX
                }
            }
        }
        else if ((self._viewWidthExtra > 0) && viewCellLastX) {
            truncateRight = self._viewWidthExtra
        }

        // Map the grid-view location to the cell-grid location.

        let gridCellX: Int = viewCellX - self._shiftCellX - ((self._shiftX > 0) ? 1 : 0)
        let gridCellY: Int = viewCellY - self._shiftCellY - ((self._shiftY > 0) ? 1 : 0)
        let foreground: CellColor = self.gridCell(gridCellX, gridCellY)?.foreground ?? self._viewBackground
        let foregroundOnly: Bool = false

        // Setup the offset for the buffer blocks.

        let shiftX: Int = (self._shiftX > 0) ? self._shiftX - self._cellSize : self._shiftX
        let shiftY: Int = (self._shiftY > 0) ? self._shiftY - self._cellSize : self._shiftY
        let offset: Int = ((self._cellSize * viewCellX) + shiftX +
                           (self._cellSize * self._viewWidth * viewCellY + shiftY * self._viewWidth)) * Screen.depth
        let size: Int = self._buffer.count

        // Loop through the blocks for the cell and write each of the indices to the buffer with the right colors/blends.
        // Being careful to truncate the left or right side of the cell appropriately (tricky stuff).

        self._buffer.withUnsafeMutableBytes { raw in

            guard let buffer: UnsafeMutableRawPointer = raw.baseAddress else { return }

            func writeCellBlock(_ block: CellGridView.BufferBlock, _ index: Int, _ count: Int)
            {
                // Uses from outer scope: buffer, offset

                let start: Int = offset + index

                guard start >= 0, (start + (count * Memory.bufferBlockSize)) <= size else {
                    //
                    // TODO
                    // At least (and only pretty sure) for the Y (vertical) case we get here on shifting;
                    // why; because we are being sloppy with the vertical, because it was easier.
                    //
                    return
                }

                let base = buffer.advanced(by: start)
                let color: UInt32

                if (block.foreground) {
                    if (block.blend != 1.0) {
                        color = CellColor.blendValueOf(foreground, self._viewBackground, amount: block.blend)
                    }
                    else {
                        color = foreground.value
                    }
                }
                else if (foregroundOnly) {
                    //
                    // Limit the write to only the foreground; can be useful
                    // for performance as background normally doesn't change.
                    //
                    return
                }
                else {
                    color = self._viewBackground.value
                }

                /*
                var rvalue = color.bigEndian
                switch count {
                case 1:
                    base.storeBytes(of: rvalue, as: UInt32.self)
                case 2:
                    base.storeBytes(of: rvalue, as: UInt32.self)
                    (base + Memory.bufferBlockSize).storeBytes(of: rvalue, as: UInt32.self)
                default:
                    memset_pattern4(base, &rvalue, count * Memory.bufferBlockSize)
                }
                */

                Memory.fastcopy(to: base, count: count, value: color)
            }

            for block in self._bufferBlocks.blocks {
                if (truncateLeft > 0) {
                    block.writeRight(width: self._viewWidth, shiftx: truncateLeft, write: writeCellBlock)
                }
                else if (truncateRight > 0) {
                    block.writeLeft(width: self._viewWidth, shiftx: truncateRight, write: writeCellBlock)
                }
                else {
                    writeCellBlock(block, block.index, block.count)
                }
            }
        }
    }

    public var shiftedBy: CellGridPoint {
        return CellGridPoint(self._viewParent.unscaled(self._shiftCellX * self._cellSize + self._shiftX),
                             self._viewParent.unscaled(self._shiftCellY * self._cellSize + self._shiftY))
    }

    public func duplicate(cellSize: Int) -> CellGridView {
        if (cellSize == self._cellSize) {
            return self
        }
        return CellGridView(viewParent: self._viewParent,
                            viewWidth: self._viewWidth,
                            viewHeight: self._viewHeight,
                            viewBackground: self._viewBackground,
                            viewTransparency: self._viewTransparency,
                            gridColumns: self._gridColumns,
                            gridRows: self._gridRows,
                            cellSize: cellSize,
                            cellPadding: self._cellPadding,
                            cellShape: self._cellShape,
                            cellFactory: self._cellFactory,
                            cells: self._cells)
    }

    public var viewColumns: Int {
        self._viewColumns + self._viewRowsExtra
    }

    public var viewRows: Int {
        self._viewRows + self._viewColumnsExtra
    }

    public var viewBackground: CellColor {
        self._viewBackground
    }

    public var gridColumns: Int {
        self._gridColumns
    }

    public var gridRows: Int {
        self._gridRows
    }

    public var gridCells: [Cell] {
        self._cells
    }

    // Note on terminology regarding input/gesture related points:
    // We say "point" to mean a pixel coordinate (coming from a gesture) which is not scaled.
    // We say "location" to mean a coordinate cell-based coordinate on the cell-grid or grid-view;
    // and by "cell-grid" we mean the virtual grid of all cells in existence, and by "grid-view"
    // we mean the viewable window (image) in which (a subset of) the cell-grid is displayed.

    // Returns the cell-grid cell object for the given grid-view input location, or nil;
    // note that the display input location is always in unscaled units.
    //
    public func gridCell<T: Cell>(_ viewPoint: CGPoint) -> T? {
        if let gridPoint: CellGridPoint = self.gridCellLocation(viewPoint) {
            return self.gridCell(gridPoint.x, gridPoint.y)
        }
        return nil
    }

    // Returns the cell-grid cell object for the given cell-grid cell location, or nil.
    //
    public func gridCell<T: Cell>(_ gridCellX: Int, _ gridCellY: Int) -> T? {
        guard gridCellX >= 0, gridCellX < self._gridColumns, gridCellY >= 0, gridCellY < self._gridRows else {
            return nil
        }
        return self._cells[gridCellY * self._gridColumns + gridCellX] as? T
    }

    // Returns the cell-grid cell location of the given grid-view input point, or nil;
    // note that the display input location is always in unscaled units.
    //
    public func gridCellLocation(_ viewPoint: CGPoint) -> CellGridPoint? {
        return self.gridCellLocation(viewPoint.x, viewPoint.y)
    }

    public func gridCellLocation(_ viewPointX: CGFloat, _ viewPointY: CGFloat) -> CellGridPoint? {

        if let viewCellLocation = self.viewCellLocation(viewPointX, viewPointY) {
            let shiftX: Int = self._viewParent.unscaled(self._shiftX)
            let shiftY: Int = self._viewParent.unscaled(self._shiftY)
            let gridCellX: Int = viewCellLocation.x - self._shiftCellX - ((shiftX > 0) ? 1 : 0)
            guard gridCellX >= 0, gridCellX < self._gridColumns else { return nil }
            let gridCellY: Int = viewCellLocation.y - self._shiftCellY - ((shiftY > 0) ? 1 : 0)
            guard gridCellY >= 0, gridCellY < self._gridRows else { return nil }
            return CellGridPoint(gridCellX, gridCellY)
        }
        return nil
    }

    public func viewCellFromGridCellLocation(_ gridCellX: Int, _ gridCellY: Int) -> CellGridPoint? {
        let shiftX: Int = self._viewParent.unscaled(self._shiftX)
        let shiftY: Int = self._viewParent.unscaled(self._shiftY)
        let viewCellX: Int = gridCellX + self._shiftCellX + ((shiftX > 0) ? 1 : 0)
        let viewCellY: Int = gridCellY + self._shiftCellY + ((shiftY > 0) ? 1 : 0)
        return CellGridPoint(viewCellX, viewCellY)
    }

    // Returns the cell location relative to the grid-view of the given grid-view input point, or nil.
    //
    public func viewCellLocation(_ viewPoint: CGPoint) -> CellGridPoint? {
        return self.viewCellLocation(viewPoint.x, viewPoint.y)
    }

    public func viewCellLocation(_ viewPointX: CGFloat, _ viewPointY: CGFloat) -> CellGridPoint? {
        guard viewPointX >= 0.0, viewPointX < CGFloat(self._viewWidth),
              viewPointY >= 0.0, viewPointY < CGFloat(self._viewHeight) else { return nil }
        let shiftX: Int = self._viewParent.unscaled(self._shiftX)
        let shiftY: Int = self._viewParent.unscaled(self._shiftY)
        let viewCellX: Int = ((shiftX > 0) ? (Int(floor(viewPointX)) + (self._cellSizeUnscaled - shiftX))
                                           : (Int(floor(viewPointX)) - shiftX)) / self._cellSizeUnscaled
        let viewCellY: Int = ((shiftY > 0) ? (Int(floor(viewPointY)) + (self._cellSizeUnscaled - shiftY))
                                           : (Int(floor(viewPointY)) - shiftY)) / self._cellSizeUnscaled
        return CellGridPoint(viewCellX, viewCellY)
    }

    public var image: CGImage? {
        var image: CGImage?
        self._buffer.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                fatalError("Buffer has no base address")
            }
            if let context = CGContext(
                data: baseAddress,
                width: self._viewWidth,
                height: self._viewHeight,
                bitsPerComponent: 8,
                bytesPerRow: self._viewWidth * Screen.depth,
                space: CellGrid.Defaults.colorSpace,
                bitmapInfo: CellGrid.Defaults.bitmapInfo
            ) {
                image = context.makeImage()
            }
        }
        return image
    }

    private func defineCell(x: Int, y: Int, foreground: CellColor)
    {
        let cell: Cell = (self._cellFactory != nil)
                         ? self._cellFactory!(self, x, y, foreground)
                         : Cell(parent: self, x: x, y: y, foreground: foreground)
        self._cells.append(cell)
    }

    private class BufferBlock
    {
        internal let index: Int
        internal let foreground: Bool
        internal let blend: Float
        internal var count: Int
        internal var lindex: Int

        init(index: Int, count: Int, foreground: Bool, blend: Float) {
            self.index = max(index, 0)
            self.count = max(count, 0)
            self.foreground = foreground
            self.blend = blend
            self.lindex = self.index
        }

        // Write blocks using the given write function IGNORING indices to the RIGHT of the given shiftx value.
        //
        internal func writeLeft(width: Int, shiftx: Int, write: CellGridView.WriteCellBlock) {
            self.writeLeftOrRight(width: width, shiftx: -shiftx, write: write)
        }

        // Write blocks using the given write function IGNORING indices to the LEFT Of the given shiftx value.
        //
        internal func writeRight(width: Int, shiftx: Int, write: CellGridView.WriteCellBlock) {
            self.writeLeftOrRight(width: width, shiftx: shiftx, write: write)
        }

        // Regarding the truncating of horizontal left or right portions of buffer blocks ...
        // Cheat sheet on shifting right (shiftX > 0); shifting vertically just falls out,
        // as well as shifting horizontally left, but not so for shifting horizontally right.
        // For example, this (WxH) grid, and the one-dimensional buffer for it ...
        //
        //       x . . .
        //       0   1   2   3   4   5
        //     +---+---+---+---+---+---+
        //     | A | B | C | J | K | L | 0  y
        //     +---+---+---+---+---+---+    .
        //     | D | E | F | M | N | O | 1  .
        //     +---+---+---+---+---+---+    .
        //     | G | H | I | P | Q | R | 2
        //     +---+---+---+---+---+---+
        //     | S | T | U | b | c | d | 3
        //     +---+---+---+---+---+---+
        //     | V | W | X | e | f | g | 4
        //     +---+---+---+---+---+---+
        //     | Y | Z | a | h | i | j | 5
        //     +---+---+---+---+---+---+
        //       ^   ^            ^   ^
        //       |   |            |   |
        //       -   -            -   -
        // If we want to ignore the 2 (S) left-most columns due to right-shift,
        // then we want to ignore (i.e. not write) buffer indices (I) where: I % W < S
        // Conversely, if we want to ignore the 2 (S) right-most columns due to left-shift,
        // then we want to ignore (i.e. not write) buffer indices (I) where: (I % W) >= (W - S)
        //
        //      0: A -> I % W ==  0 % 6 == 0 <<< ignore on rshift-2: A
        //      1: B -> I % W ==  1 % 6 == 1 <<< ignore on rshift-2: B
        //      2: C -> I % W ==  2 % 6 == 2
        //      3: J -> I % W ==  3 % 6 == 3
        //      4: K -> I % W ==  4 % 6 == 4 <<< ignore on lshift-2: K
        //      5: L -> I % W ==  5 % 6 == 5 <<< ignore on lshift-2: L
        //      6: D -> I % W ==  6 % 6 == 0 <<< ignore on rshift-2: D
        //      7: E -> I % W ==  7 % 6 == 1 <<< ignore on rshift-2: E
        //      8: F -> I % W ==  8 % 6 == 2
        //      9: M -> I % W ==  9 % 6 == 3
        //     10: N -> I % W == 10 % 6 == 4 <<< ignore on lshift-2: N
        //     11: O -> I % W == 11 % 6 == 5 <<< ignore on lshift-2: O
        //     12: G -> I % W == 12 % 6 == 0 <<< ignore on rshift-2: G
        //     13: H -> I % W == 13 % 6 == 1 <<< ignore on rshift-2: H
        //     14: I -> I % W == 14 % 6 == 2
        //     15: P -> I % W == 15 % 6 == 3
        //     16: Q -> I % W == 16 % 6 == 4 <<< ignore on lshift-2: Q
        //     17: R -> I % W == 17 % 6 == 5 <<< ignore on lshift-2: R
        //     18: S -> I % W == 18 % 6 == 0 <<< ignore on rshift-2: S
        //     19: T -> I % W == 19 % 6 == 1 <<< ignore on rshift-2: T
        //     20: U -> I % W == 20 % 6 == 2
        //     21: b -> I % W == 21 % 6 == 3
        //     22: c -> I % W == 22 % 6 == 4 <<< ignore on lshift-2: c
        //     23: d -> I % W == 23 % 6 == 5 <<< ignore on lshift-2: d
        //     24: V -> I % W == 24 % 6 == 0 <<< ignore on rshift-2: V
        //     25: W -> I % W == 25 % 6 == 1 <<< ignore on rshift-2: W
        //     26: X -> I % W == 26 % 6 == 2
        //     27: e -> I % W == 27 % 6 == 3
        //     28: f -> I % W == 28 % 6 == 4 <<< ignore on lshift-2: f
        //     29: g -> I % W == 29 % 6 == 5 <<< ignore on lshift-2: g
        //     30: Y -> I % W == 30 % 6 == 0 <<< ignore on rshift-2: Y
        //     31: Z -> I % W == 31 % 6 == 1 <<< ignore on rshift-2: Z
        //     32: a -> I % W == 32 % 6 == 2
        //     33: h -> I % W == 33 % 6 == 3
        //     34: i -> I % W == 34 % 6 == 4 <<< ignore on lshift-2: i
        //     35: j -> I % W == 35 % 6 == 5 <<< ignore on lshift-2: j
        //
        // If we want to ignore the 2 (S) top-most columns due to down-shift,
        // then we want to ignore (i.e. not write) buffer indices (I) where: I / W < S
        // Conversely, if we want to ignore the 2 (S) bottom-most columns due to up-shift,
        // then we want to ignore (i.e. not write) buffer indices (I) where: I / W >= (W - S)
        //
        // Note: ⬥  i = y * w + x  ⬥   x = i % w  ⬥   y = i / w  ⬥
        //
        // Note that the BufferBlock.index is a byte index into the buffer,
        // i.e. it already has Screen.depth factored into it; and note that
        // the BufferBlock.count refers to the number of 4-byte (UInt32) values,

        // Write blocks using the given write function IGNORING indices which correspond to
        // a shifting left or right by the given (shiftx) amount; tricky due to the row-major
        // organization of grid cells/pixels in the one-dimensional buffer array.
        //
        // A positive shiftx means to truncate the values (pixels) LEFT of the given shiftx value; and
        // a negative shiftx means to truncate the values (pixels) RIGHT of the given shiftx value; and
        // A positive shifty means to truncate the values (pixels) UP from the given shifty value, and
        // a negative shifty means to truncate the values (pixels) DOWN from the given shifty value.
        //
        internal func writeLeftOrRight(width: Int, shiftx: Int, write: CellGridView.WriteCellBlock) {
            let shiftw = abs(shiftx)
            let shiftl: Bool = (shiftx < 0)
            let shiftr: Bool = (shiftx > 0)
            let bindex = self.index
            let bsize = Memory.bufferBlockSize
            var index: Int? = nil
            var count = 0
            for i in 0..<self.count {
                let starti = bindex + i * bsize
                let shift = (starti / bsize) % width
                if ((shiftr && (shift >= shiftw)) || (shiftl && (shift < shiftw))) {
                    if (index == nil) {
                        index = starti
                        count = 1
                    } else {
                        count += 1
                    }
                } else {
                    if let j = index {
                        write(self, j, count)
                        if (shiftr && (shift > shiftw)) { break }
                        else if (shiftl && (shift >= shiftw)) { break }
                        index = nil
                        count = 0
                    } else {
                        if (shiftr && (shift > shiftw)) { break }
                        else if (shiftl && (shift >= shiftw)) { break }
                    }
                }
            }
            if let j = index {
                write(self, j, count)
            }
        }
    }

    private class BufferBlocks
    {
        private let _width: Int
        private var _blocks: [BufferBlock] = []
        private var _blocksHollow: [BufferBlock]? = nil

        init(width: Int) {
            self._width = width
        }

        internal var blocks: [BufferBlock] {
            self._blocks
        }

        internal func append(_ index: Int, foreground: Bool, blend: Float) {
            if let last = self._blocks.last,
                    last.foreground == foreground,
                    last.blend == blend,
                    index == last.lindex + Memory.bufferBlockSize {
                last.count += 1
                last.lindex = index
            } else {
                self._blocks.append(BufferBlock(index: index, count: 1, foreground: foreground, blend: blend))
            }
        }

        internal func createHollowBlocks() -> [BufferBlock]? {

            let cellSize: Int = 43 // TODO
            let cellPadding: Int = 1 // TODO

            func findLargestSolidInnerBlock() -> Int? {

                let innerCellSize: Int? = nil
                let cellSizeMinusPadding: Int = cellSize - cellPadding * 2

                func isSolidSquareBlock(_ innerCellSize: Int) -> Bool {
                    let startxy: Int = cellSize - innerCellSize
                    let endxy: Int = cellSize - startxy - 1
                    var found: Bool = true
                    for block in self._blocks {
                        for index in stride(from: block.index, to: block.index + block.count * Memory.bufferBlockSize, by: Memory.bufferBlockSize) {
                            let x = (index % self._width) / Memory.bufferBlockSize
                            let y = (index / self._width) / Memory.bufferBlockSize
                            if ((x >= startxy) && (x <= endxy) && (y >= startxy) && (y <= endxy)) {
                                if (!block.foreground || (block.blend != 1.0)) {
                                    found = false
                                    break
                                }
                            }
                        }
                    }
                    return found
                }

                let outerMostCellSize: Int = cellSize - cellPadding * 2
                let innerMostCellSize: Int = outerMostCellSize - outerMostCellSize / 2 + 4
                for size in stride(from: outerMostCellSize, through: innerMostCellSize, by: -1) {
                    if (isSolidSquareBlock(size)) {
                        return size
                    }
                }

                return nil
            }

            var blocksHollow: BufferBlocks = BufferBlocks(width: self._width)
            let innerCellSize: Int? = findLargestSolidInnerBlock()

            if (innerCellSize != nil) {
                let startxy: Int = cellSize - innerCellSize!
                let endxy: Int = cellSize - startxy - 1
                for block in self._blocks {
                    for index in stride(from: block.index, to: block.index + block.count * Memory.bufferBlockSize, by: Memory.bufferBlockSize) {
                        let x = (index % self._width) / Memory.bufferBlockSize
                        let y = (index / self._width) / Memory.bufferBlockSize
                        if (((x < startxy) || (x > endxy)) && ((y < startxy) || (y > endxy))) {
                            blocksHollow.append(block.index, foreground: block.foreground, blend: block.blend)
                        }
                    }
                }
                return blocksHollow._blocks
            }
            return nil
        }

        internal static func createBufferBlocks(bufferSize: Int,
                                               displayWidth: Int,
                                               displayHeight: Int,
                                               cellSize: Int,
                                               cellPadding: Int,
                                               cellShape: CellShape,
                                               cellTransparency: UInt8) -> BufferBlocks
        {
            let blocks: BufferBlocks = BufferBlocks(width: displayWidth)
            let padding: Int = ((cellPadding > 0) && (cellShape != .square))
                               ? (((cellPadding * 2) >= cellSize)
                                 ? ((cellSize / 2) - 1)
                                 : cellPadding) : 0
            let size: Int = cellSize - (2 * padding)
            let shape: CellShape = (size < 3) ? .inset : cellShape
            let fade: Float = 0.6  // smaller is smoother

            for dy in 0..<cellSize {
                for dx in 0..<cellSize {
    
                    if ((dx >= displayWidth) || (dy >= displayHeight)) { continue }
                    if ((dx < 0) || (dy < 0)) { continue }
                    var coverage: Float = 0.0

                    switch shape {
                    case .square, .inset:
                        if ((dx >= padding) && (dx < cellSize - padding) &&
                            (dy >= padding) && (dy < cellSize - padding)) {
                            coverage = 1.0
                        }

                    case .circle:
                        let fx: Float = Float(dx) + 0.5
                        let fy: Float = Float(dy) + 0.5
                        let centerX: Float = Float(cellSize / 2)
                        let centerY: Float = Float(cellSize / 2)
                        let dxsq: Float = (fx - centerX) * (fx - centerX)
                        let dysq: Float = (fy - centerY) * (fy - centerY)
                        let circleRadius: Float = Float(size) / 2.0
                        let d: Float = circleRadius - sqrt(dxsq + dysq)
                        coverage = max(0.0, min(1.0, d / fade))

                    case .rounded:
                        let fx: Float = Float(dx) + 0.5
                        let fy: Float = Float(dy) + 0.5
                        let cornerRadius: Float = Float(size) * 0.25
                        let minX: Float = Float(padding)
                        let minY: Float = Float(padding)
                        let maxX: Float = Float(cellSize - padding)
                        let maxY: Float = Float(cellSize - padding)
                        if ((fx >= minX + cornerRadius) && (fx <= maxX - cornerRadius)) {
                            if ((fy >= minY) && (fy <= maxY)) {
                                coverage = 1.0
                            }
                        } else if ((fy >= minY + cornerRadius) && (fy <= maxY - cornerRadius)) {
                            if ((fx >= minX) && (fx <= maxX)) {
                                coverage = 1.0
                            }
                        } else {
                            let cx: Float = fx < (minX + cornerRadius) ? minX + cornerRadius :
                                            fx > (maxX - cornerRadius) ? maxX - cornerRadius : fx
                            let cy: Float = fy < (minY + cornerRadius) ? minY + cornerRadius :
                                            fy > (maxY - cornerRadius) ? maxY - cornerRadius : fy
                            let dx: Float = fx - cx
                            let dy: Float = fy - cy
                            let d: Float = cornerRadius - sqrt(dx * dx + dy * dy)
                            coverage = max(0.0, min(1.0, d / fade))
                        }
                    }

                    let index: Int = (dy * displayWidth + dx) * Screen.depth
                    if ((index >= 0) && ((index + (Screen.depth - 1)) < bufferSize)) {
                        if (coverage > 0) {
                            blocks.append(index, foreground: true, blend: coverage)
    
                        } else {
                            blocks.append(index, foreground: false, blend: 0.0)
                        }
                    }
                }
            }

            blocks._blocksHollow = blocks.createHollowBlocks()
            return blocks
        }
    }

    typealias PreferredSize = (cellSize: Int, displayWidth: Int, displayHeight: Int)

    // Returns a list of preferred sizes for the cell size, such that the fit evenly without bleeding out
    // past the end; the given dimensions, as well as the returned ones, are assumed to unscaled values;
    //
    public static func preferredCellSizes(_ displayWidth: Int,
                                          _ displayHeight: Int,
                                          cellPreferredSizeMarginMax: Int = CellGrid.Defaults.cellPreferredSizeMarginMax)
                                          -> [PreferredSize] {
        let mindim: Int = min(displayWidth, displayHeight)
        guard mindim > 0 else { return [] }
        var results: [PreferredSize] = []
        for cellSize in 1...mindim {
            let ncols: Int = displayWidth / cellSize
            let nrows: Int = displayHeight / cellSize
            let usedw: Int = ncols * cellSize
            let usedh: Int = nrows * cellSize
            let leftx: Int = displayWidth - usedw
            let lefty: Int = displayHeight - usedh
            if ((leftx <= cellPreferredSizeMarginMax) && (lefty <= cellPreferredSizeMarginMax)) {
                results.append((cellSize: cellSize, displayWidth: usedw, displayHeight: usedh))
            }
        }
        return results
    }

    public static func closestPreferredCellSize(in list: [PreferredSize], to target: Int) -> PreferredSize? {
        return list.min(by: {
            let a: Int = abs($0.cellSize - target)
            let b: Int = abs($1.cellSize - target)
            return (a, $0.cellSize) < (b, $1.cellSize)
        })
    }
}
