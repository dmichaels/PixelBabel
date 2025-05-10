import Foundation
import SwiftUI
import Utils

// A main purpose of this (as first created) is for keeping track of the backing pixel buffer
// indices for the (canonical) cell; for the purpose of being able to write the values very fast
// using block memory copy (see Memory.fastcopy). It is ASSUMED that the abufferBlocksddBufferItem function is
// called with indices which are monotonically increasing, and are not duplicated or out of order
// or anything weird; assume called from the buffer setting loop in the PixelMap._write method.
//

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
    private var _cells: [Cell]
    private var _buffer: [UInt8]
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
         cellFactory: CellFactory? = nil)
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
        self._cells = []
        self._buffer = [UInt8](repeating: 0, count: self._viewWidth * self._viewHeight * Screen.depth)
        self._bufferBlocks = CellGridView.createBufferBlocks(bufferSize: self._buffer.count,
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

        for y in 0..<self._gridRows {
            for x in 0..<self._gridColumns {
                self.defineCell(x: x, y: y, foreground: CellGrid.Defaults.cellForeground)
            }
        }
    }

    public func shift(shiftx: Int = 0, shifty: Int = 0)
    {
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

        if (shiftCellX >= self._viewCellEndX) {
            shiftCellX = self._viewCellEndX
            shiftX = 0
        }
        else if (-shiftCellX >= self._gridCellEndX) {
            shiftCellX = -self._gridCellEndX
            shiftX = 0
        }
        if (shiftCellY >= self._viewCellEndY) {
            shiftCellY = self._viewCellEndY
            shiftY = 0
        }
        else if (-shiftCellY >= self._gridCellEndY) {
            shiftCellY = -self._gridCellEndY
            shiftY = 0
        }

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
    }

    // Draws at the given grid view cell location (viewCellX, viewCellY), the grid cell currently corresponding
    // to that location, taking into account the current shiftCellX/Y and shiftX/Y values, i.e. the cell and
    // pixel level based shift values, negative meaning to shift the grid cell left or up, and positive
    // meaning to shift the grid cell right or down.
    //
    private func writeCell(viewCellX: Int, viewCellY: Int)
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
        let foreground = self.gridCell(gridCellX, gridCellY)?.foreground ?? self._viewBackground
        let foregroundOnly = false

        // Setup the offset for the buffer blocks.

        let shiftX = (self._shiftX > 0) ? self._shiftX - self._cellSize : self._shiftX
        let shiftY = (self._shiftY > 0) ? self._shiftY - self._cellSize : self._shiftY
        let offset: Int = ((self._cellSize * viewCellX) + shiftX +
                           (self._cellSize * self._viewWidth * viewCellY + shiftY * self._viewWidth)) * Screen.depth
        let size: Int = self._buffer.count

        self._buffer.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            for block in self._bufferBlocks.blocks {
                if (truncateLeft > 0) {
                    let truncatedBlocks = CellGridView.BufferBlocks.truncateLeft(block,
                                                                                 offset: offset,
                                                                                 width: self._viewWidth,
                                                                                 shiftx: truncateLeft)
                    for block in truncatedBlocks {
                        writeCellBlock(buffer: base, block: block)
                    }
                    continue
                }
                else if (truncateRight > 0) {
                    let truncatedBlocks = CellGridView.BufferBlocks.truncateRight(block,
                                                                                  offset: offset,
                                                                                  width: self._viewWidth,
                                                                                  shiftx: truncateRight)
                    for block in truncatedBlocks {
                        writeCellBlock(buffer: base, block: block)
                    }
                    continue
                }
                writeCellBlock(buffer: base, block: block)
            }
        }

        // Writes the given buffer block to the backing image (pixel value) buffer; each block describing a
        // range of indices and whether the block is for a foreground or background color, and the amount
        // it should be blended with the background if it is for a foreground color).
        // N.B. From outer function scope: offset, size, foreground, foregroundOnly
        // N.B. From class scope: self._viewBackground
        //
        func writeCellBlock(buffer: UnsafeMutableRawPointer, block: CellGridView.BufferBlock)  {

            func blend(_ a: UInt8, _ b: UInt8, amount: Float) -> UInt8 {
                return UInt8(Float(a) * amount + Float(b) * (1 - amount))
            }

            let start: Int = offset + block.index

            guard start >= 0, (start + (block.count * Memory.bufferBlockSize)) <= size else {
                return
            }

            let base = buffer.advanced(by: start)
            let color: CellColor

            if (block.foreground) {
                if (block.blend != 0.0) {
                    color = CellColor(blend(foreground.red,   self._viewBackground.red,   amount: block.blend),
                                      blend(foreground.green, self._viewBackground.green, amount: block.blend),
                                      blend(foreground.blue,  self._viewBackground.blue,  amount: block.blend),
                                      alpha: foreground.alpha)
                }
                else {
                    color = foreground
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
                color = self._viewBackground
            }

            Memory.fastcopy(to: base, count: block.count, value: color.value)
        }
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

    // Returns the cell-grid cell object for the given grid-view input location, or nil;
    // note that the display input location is always in unscaled units.
    //
    public func gridCell<T: Cell>(_ viewLocation: CGPoint) -> T? {
        if let gridPoint: CellGridPoint = self.locate(viewLocation) {
            return self.gridCell(gridPoint.x, gridPoint.y)
        }
        return nil
    }

    // Returns the cell-grid cell object for the given cell-grid x/y cell location, or nil.
    //
    public func gridCell<T: Cell>(_ gridCellX: Int, _ gridCellY: Int) -> T? {
        guard gridCellX >= 0, gridCellX < self._gridColumns, gridCellY >= 0, gridCellY < self._gridRows else {
            return nil
        }
        return self._cells[gridCellY * self._gridColumns + gridCellX] as? T
    }

    // Returns the cell-grid cell location for the given grid-view input location, or nil;
    // note that the display input location is always in unscaled units.
    //
    public func locate(_ viewLocation: CGPoint) -> CellGridPoint? {
        let viewPoint: CellGridPoint = CellGridPoint(viewLocation)
        guard viewPoint.x >= 0, viewPoint.x < self._viewWidthUnscaled,
              viewPoint.y >= 0, viewPoint.y < self._viewHeightUnscaled else {
            return nil
        }
        let viewCellX = viewPoint.x / self._cellSizeUnscaled
        let viewCellY = viewPoint.y / self._cellSizeUnscaled
        let gridCellX = viewCellX - self._shiftCellX - self._viewColumnsExtra
        let gridCellY = viewCellY - self._shiftCellY - self._viewRowsExtra
        guard gridCellX >= 0, gridCellX < self._gridColumns, gridCellY >= 0, gridCellY < self._gridRows else {
            return nil
        }
        return CellGridPoint(gridCellX, gridCellY)
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
        let index: Int
        let foreground: Bool
        let blend: Float
        var count: Int
        var lindex: Int

        init(index: Int, count: Int, foreground: Bool = true, blend: Float = 0.0) {
            self.index = max(index, 0)
            self.count = max(count, 0)
            self.foreground = foreground
            self.blend = blend
            self.lindex = self.index
        }
    }

    private class BufferBlocks
    {
        var blocks: [BufferBlock] = []

        internal func append(_ index: Int, foreground: Bool, blend: Float = 0.0) {
            if let last = self.blocks.last, last.foreground == foreground, last.blend == blend,
                        index == last.lindex + Memory.bufferBlockSize {
                last.count += 1
                last.lindex = index
            } else {
                self.blocks.append(BufferBlock(index: index, count: 1, foreground: foreground, blend: blend))
            }
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
        // If we want to ignore the 2 (S) left-most columns due to right shift,
        // then we want to ignore (i.e. not write) buffer indices (I) where: I % W < S
        // Conversely, if we want to ignore the 2 (S) right-most columns due to left shift,
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
        // Note that the BufferBlock.index is a byte index into the buffer,
        // i.e. it already has Screen.depth factored into it; and note that
        // the BufferBlock.count refers to the number of 4-byte (UInt32) values,

        // Ignore blocks to the left of the given shiftx value.
        //
        static func truncateLeft(_ block: BufferBlock, offset: Int, width: Int, shiftx: Int) -> [BufferBlock] {
            return BufferBlocks.truncateX(block, offset: offset, width: width, shiftx: shiftx)
        }

        // Ignore blocks to the right of the given shiftx value.
        //
        static func truncateRight(_ block: BufferBlock, offset: Int, width: Int, shiftx: Int) -> [BufferBlock] {
            return BufferBlocks.truncateX(block, offset: offset, width: width, shiftx: -shiftx)
        }

        // Returns a new BufferBlock list for this/self one (possibly empty) which eliminates indices
        // which correspond to a shifting left or right by the given (shiftx) amount; this was tricky,
        // due to the row-major organization of grid cells/pixels in the one-dimensional buffer array.
        // A positive shiftx means to truncate the values (pixels) LEFT of the given shiftx value, and
        // a negative shiftx means to truncate the values (pixels) RIGHT of the given shiftx value.
        //
        static func truncateX(_ block: BufferBlock, offset: Int, width: Int, shiftx: Int) -> [BufferBlock] {
            var blocks: [BufferBlock] = []
            var start: Int? = nil
            var count = 0
            let shiftw = abs(shiftx)
            for i in 0..<block.count {
                let starti = block.index + i * Memory.bufferBlockSize
                let shift = (starti / Memory.bufferBlockSize) % width
                //
                // This the below uncommented if-expression was suggested by ChatGPT as a simplification
                // of this if-expression; it is still not entirely clear to me why/how these are equivalent:
                //
                //  (((shiftx > 0) && (shift >= shiftw)) || ((shiftx < 0) && (shift < shiftw)))
                //
                if ((shiftx != 0) && ((shiftx > 0) == (shift >= shiftw))) {
                    if (start == nil) {
                        start = starti
                        count = 1
                    } else {
                        count += 1
                    }
                } else if (start != nil) {
                    blocks.append(BufferBlock(index: start!, count: count,
                                              foreground: block.foreground, blend: block.blend))
                    start = nil
                    count = 0
                }
            }
            if (start != nil) {
                blocks.append(BufferBlock(index: start!, count: count,
                                          foreground: block.foreground, blend: block.blend))
            }
            return blocks
        }
    }

    private static func createBufferBlocks(bufferSize: Int,
                                           displayWidth: Int,
                                           displayHeight: Int,
                                           cellSize: Int,
                                           cellPadding: Int,
                                           cellShape: CellShape,
                                           cellTransparency: UInt8) -> BufferBlocks
    {
        let blocks: BufferBlocks = BufferBlocks()
        let padding: Int = ((cellPadding > 0) && (cellShape != .square))
                           ? (((cellPadding * 2) >= cellSize)
                             ? ((cellSize / 2) - 1)
                             : cellPadding) : 0
        let size = cellSize - (2 * padding)
        let shape = (size < 3) ? .inset : cellShape
        let fade: Float = 0.6  // smaller is smoother

        for dy in 0..<cellSize {
            for dx in 0..<cellSize {

                if dx >= displayWidth || dy >= displayHeight { continue }
                if dx < 0 || dy < 0 { continue }
                let fx: Float = Float(dx) + 0.5
                let fy: Float = Float(dy) + 0.5
                var coverage: Float = 0.0

                switch shape {
                case .square, .inset:
                    if ((dx >= padding) && (dx < cellSize - padding) &&
                        (dy >= padding) && (dy < cellSize - padding)) {
                        coverage = 1.0
                    }

                case .circle:
                    let centerX: Float = Float(cellSize / 2)
                    let centerY: Float = Float(cellSize / 2)
                    let dxsq: Float = (fx - centerX) * (fx - centerX)
                    let dysq: Float = (fy - centerY) * (fy - centerY)
                    let circleRadius: Float = Float(size) / 2.0
                    let d: Float = circleRadius - sqrt(dxsq + dysq)
                    coverage = max(0.0, min(1.0, d / fade))

                case .rounded:
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
                        blocks.append(index, foreground: false)
                    }
                }
            }
        }

        return blocks
    }

    typealias PreferredSize = (cellSize: Int, displayWidth: Int, displayHeight: Int)

    // Returns a list of preferred sizes for the cell size, such that the fit evenly without bleeding out
    // past the end; the given dimensions, as well as the returned ones, are assumed to unscaled values;
    //
    public static func preferredCellSizes(_ displayWidth: Int,
                                          _ displayHeight: Int,
                                          cellPreferredSizeMarginMax: Int = CellGrid.Defaults.cellPreferredSizeMarginMax)
                                          -> [PreferredSize] {
        let mindim = min(displayWidth, displayHeight)
        guard mindim > 0 else { return [] }
        var results: [(cellSize: Int, displayWidth: Int, displayHeight: Int)] = []
        for cellSize in 1...mindim {
            let ncols = displayWidth / cellSize
            let nrows = displayHeight / cellSize
            let usedw = ncols * cellSize
            let usedh = nrows * cellSize
            let leftx = displayWidth - usedw
            let lefty = displayHeight - usedh
            if ((leftx <= cellPreferredSizeMarginMax) && (lefty <= cellPreferredSizeMarginMax)) {
                results.append((cellSize: cellSize, displayWidth: usedw, displayHeight: usedh))
            }
        }
        return results
    }

    public static func closestPreferredCellSize(in list: [PreferredSize], to target: Int) -> PreferredSize? {
        return list.min(by: {
            let a = abs($0.cellSize - target)
            let b = abs($1.cellSize - target)
            return (a, $0.cellSize) < (b, $1.cellSize)
        })
    }
}
