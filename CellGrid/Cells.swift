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
class Cells
{
    public func setView(cells: [Cell], ncolumns: Int, nrows: Int, x: Int, y: Int, shiftx: Int = 0, shifty: Int = 0)
    {
        guard x >= 0, y >= 0, x < ncolumns, y < nrows else {
            return
        }

        func cell<T: Cell>(x: Int, y: Int) -> T? {
            return cells[y * ncolumns + x] as? T
        }

        let cellColumns: Int = ncolumns
        let cellRows: Int = nrows
        let cellEndX: Int = cellColumns - 1
        let cellEndY: Int = cellRows - 1

        // These will go somewhere else; in some View calss or something ...
        //
        let viewWidth: Int = self._displayWidth
        let viewHeight: Int = self._displayHeight
        let viewCellColumns: Int = viewWidth / self._cellSize 
        let viewCellRows: Int = viewHeight / self._cellSize 
        let viewCellEndX: Int = viewCellColumns - 1
        let viewCellEndY: Int = viewCellRows - 1

        // Normalize the pixel-level shift to cell-level and pixel-level.
        //
        var shiftX: Int = self._grid.scaled(shiftx), shiftCellX: Int
        var shiftY: Int = self._grid.scaled(shifty), shiftCellY: Int

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

        // Restrict shift to min/max.
        //
        if (shiftCellX >= viewCellEndX) {
            shiftCellX = viewCellEndX
            shiftX = 0
        }
        else if (-shiftCellX >= cellEndX) {
            shiftCellX = cellEndX
            shiftX = 0
        }
        if (shiftCellY >= viewCellEndY) {
            shiftCellY = viewCellEndY
            shiftY = 0
        }
        else if (-shiftCellY >= cellEndY) {
            shiftCellY = cellEndY
            shiftY = 0
        }
        let writeBlankCells: Bool = true

        // TODO ...
        //
        let viewCellExtraX = (shiftCellX != 0) ? 1 : 0
        let viewCellExtraY = (shiftCellY != 0) ? 1 : 0

        for vy in 0..<(viewCellRows /*+ viewCellExtraY*/) {
            for vx in 0..<(viewCellColumns /*+ viewCellExtraX*/) {
                let cellX: Int = vx - shiftCellX - viewCellExtraX
                let cellY: Int = vy - shiftCellY - viewCellExtraY
                if vy == 0 {
                    var x = 1
                }
                if ((cellX < 0) || (cellY < 0)) { // ((vx < shiftCellX) || (vy < shiftCellY))
                    if (writeBlankCells) {
                        self.writeCell(x: vx, y: vy,
                                       shiftx: shiftX, shifty: shiftY,
                                       foreground: CellColor(Color.red), // self._cellBackground,
                                       background: CellColor(Color.red), // self._cellBackground,
                                       limit: false)
                    }
                    continue
                }
                if let cell: Cell = cell(x: cellX, y: cellY) {
                    self.writeCell(x: vx, y: vy,
                                   shiftx: shiftX, shifty: shiftY,
                                   foreground: cell.foreground,
                                   background: self._cellBackground, limit: false)
                }
            }
        }
    }

    public func old_setView(cells: [Cell], ncolumns: Int, nrows: Int, x: Int, y: Int, shiftx: Int = 0, shifty: Int = 0)
    {
        func cell<T: Cell>(x: Int, y: Int) -> T? {
            guard x >= 0, y >= 0, x < ncolumns, y < nrows else {
                return nil
            }
            return cells[y * ncolumns + x] as? T
        }

        let shiftX = self._grid.scaled(shiftx)
        let shiftY = self._grid.scaled(shifty)

        /*
        let viewCellWidth = self._displayWidth / self._cellSize 
        let viewCellHeight = self._displayHeight / self._cellSize 

        let shiftCellX = shiftX / self._cellSize
        let shiftCellY = shiftY / self._cellSize

        let startCellX = x - shiftCellX
        let endCellX = ? // startCellX + viewCellWidth + (shiftX != 0 ? 1 : 0) - 1 
        let endCellX = startCellX + self.ncolumns + (shiftX != 0 ? 1 : 0) - 1 
        let startCellY = y - shiftCellY
        let endCellY = ? // startCellY + viewCellHeight + (shiftY != 0 ? 1 : 0) - 1 
        */

        let startCellX = x - (shiftX / self._cellSize)
        let endCellX = startCellX + self.ncolumns + (shiftX != 0 ? 1 : 0) - 1 
        let startCellY = y - (shiftY / self._cellSize)
        let endCellY = startCellY + self.nrows + (shiftY != 0 ? 1 : 0) - 1 

        let viewStartCellX = (shiftx > 0) ? startCellX + (self._cellSize / shiftx) : startCellX
        let viewEndCellX = (shiftx < 0) ? endCellX - (self._cellSize / -shiftx) : endCellX

        for row in startCellY...endCellY{
            for column in startCellX...endCellX {
                if let cell: Cell = cell(x: column, y: row) {
                    print("WC: [\(column),\(row)] = [\(cell.x),\(cell.y)] SXY: [\(startCellX),\(endCellX)] TL: \(shiftx != 0 && column == startCellX) TR: \(shiftx != 0 && column == endCellX))")
                    // self.writeCell(x: cell.x, y: cell.y,
                    self.writeCell(x: column, y: row,
                                   shiftx: shiftx, shifty: shifty, // NOTE UNSCALED FOR THIS VERSION OF writeCell (it does scaling)
                                   foreground: cell.foreground, background: cell.background,
                                   limit: false,
                                   truncateLeft: shiftx != 0 && column == startCellX,
                                   truncateRight: shiftx != 0 && column == endCellX)
                    /*
                    Cells.writeCell(buffer: &self._buffer,
                                    cellSize: self._cellSize,
                                    cellBlocks: self._bufferBlocks.blocks,
                                    cellX: cell.x,
                                    cellY: cell.y,
                                    cellForeground: cell.foreground,
                                    cellBackground: cell.background,
                                    cellForegroundOnly: false,
                                    shiftX: self._grid.scaled(0),
                                    shiftY: self._grid.scaled(0),
                                    // shiftX: self._grid.scaled(200),
                                    // shiftY: self._grid.scaled(200),
                                    viewWidth: self._displayWidth,
                                    viewHeight: self._displayHeight)
                    */
                }
            }
        }
    }

    typealias PreferredSize = (cellSize: Int, displayWidth: Int, displayHeight: Int)

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

        func dump(verbose: Bool = false, code: Bool = false, width: Int = 0) {
            if verbose {
                for i in 0..<self.count {
                    let index = self.index + i * Memory.bufferBlockSize
                    print("BLOCK>" +
                          " INDEX: \(String(format: "%08d", index))" +
                          (i == 0 ? " COUNT: \(String(format: "%3d", self.count))" : "   ...:   -") +
                          "  \(self.foreground ? "FG" : "BG")-\(String(format: "%.1f", self.blend))" +
                          (width > 0 ? " -> [\(index % width), \(index / width)]" : ""))
                }
            }
            else {
                print("block>" +
                      " index: \(String(format: "%08d", self.index))" +
                      " count: \(String(format: "%3d", self.count))" +
                      "  \(self.foreground ? "FG" : "BG")-\(String(format: "%.1f", self.blend))")
            }
            if code {
                print("blocks.append(BufferBlock(index: \(self.index), count: \(self.count), foreground: \(self.foreground), blend: \(self.blend)))")
            }
        }
    }

    private class BufferBlocks
    {
        var blocks: [BufferBlock] = []

        func append(index: Int, foreground: Bool, blend: Float = 0.0) {
            if let last = self.blocks.last, last.foreground == foreground, last.blend == blend,
                        index == last.lindex + Memory.bufferBlockSize {
                last.count += 1
                last.lindex = index
            } else {
                self.blocks.append(BufferBlock(index: index, count: 1, foreground: foreground, blend: blend))
            }
        }

        // Ignore blocks to the left of the given shiftx value.
        //
        static func truncateLeftOf(_ block: BufferBlock, offset: Int, width: Int, shiftx: Int) -> [BufferBlock] {
            return BufferBlocks.truncateX(block, offset: offset, width: width, shiftx: shiftx)
        }

        // Ignore blocks to the right of the given shiftx value.
        //
        static func truncateRightOf(_ block: BufferBlock, offset: Int, width: Int, shiftx: Int) -> [BufferBlock] {
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
            // let shiftw = (shiftx > 0) ? shiftx : ((shiftx < 0) ? (width + shiftx) : 0)
            // let shiftw = (shiftx > 0) ? shiftx : ((shiftx < 0) ? -shiftx : 0)
            let shiftw = abs(shiftx)
            for i in 0..<block.count {
                // let starti = offset + block.index + i * Memory.bufferBlockSize
                let starti = /*offset +*/ block.index + i * Memory.bufferBlockSize
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
                    // blocks.append(BufferBlock(index: start! - offset, count: count,
                    blocks.append(BufferBlock(index: start! /*- offset*/, count: count,
                                              foreground: block.foreground, blend: block.blend))
                    start = nil
                    count = 0
                }
            }
            if (start != nil) {
                // blocks.append(BufferBlock(index: start! - offset, count: count,
                blocks.append(BufferBlock(index: start! /*- offset*/, count: count,
                                          foreground: block.foreground, blend: block.blend))
            }
            return blocks
        }
        static func old_truncateX(_ block: BufferBlock, offset: Int, width: Int, shiftx: Int) -> [BufferBlock] {
            var blocks: [BufferBlock] = []
            var start: Int? = nil
            var count = 0
            // let shiftw = (shiftx > 0) ? shiftx : ((shiftx < 0) ? (width + shiftx) : 0)
            // let shiftw = (shiftx > 0) ? shiftx : ((shiftx < 0) ? -shiftx : 0)
            let shiftw = abs(shiftx)
            for i in 0..<block.count {
                let starti = offset + block.index + i * Memory.bufferBlockSize
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
                    blocks.append(BufferBlock(index: start! - offset, count: count,
                                              foreground: block.foreground, blend: block.blend))
                    start = nil
                    count = 0
                }
            }
            if (start != nil) {
                blocks.append(BufferBlock(index: start! - offset, count: count,
                                          foreground: block.foreground, blend: block.blend))
            }
            return blocks
        }
    }

    private let _grid: CellGrid
    private let _displayWidth: Int
    private let _displayHeight: Int
    private let _displayWidthUnscaled: Int
    private let _displayHeightUnscaled: Int
    private let _displayScale: CGFloat
    private let _displayScaling: Bool
    private let _cellSize: Int
    private let _cellSizeUnscaled: Int
    private let _cellPadding: Int
    private let _cellShape: CellShape
    private let _cellTransparency: UInt8
    private let _cellBleed: Bool
    private let _cellBackground: CellColor
    private let _cellFactory: Cell.Factory?
    private var _cells: [Cell]
    private var _buffer: [UInt8]
    private let _bufferBlocks: BufferBlocks

    init(grid: CellGrid,
         displayWidth: Int,
         displayHeight: Int,
         displayScale: CGFloat,
         displayScaling: Bool,
         cellSize: Int,
         cellPadding: Int,
         cellShape: CellShape,
         cellTransparency: UInt8,
         cellBleed: Bool,
         cellForeground: CellColor,
         cellBackground: CellColor,
         cellFactory: Cell.Factory? = nil) {

        // Here (unlike in CellGrid) we assume given argument are already scaled as appropriate;
        // and that displayScaling is set correspondingly correctly; we only need to unscale
        // to map screen input (tap etc) locations since these are always unscaled.

        self._grid = grid
        self._displayScale = displayScale
        self._displayScaling = displayScaling
        self._displayWidth = displayWidth
        self._displayHeight = displayHeight
        self._displayWidthUnscaled = grid.unscaled(displayWidth)
        self._displayHeightUnscaled = grid.unscaled(displayHeight)
        self._cellSize = cellSize
        self._cellSizeUnscaled = grid.unscaled(cellSize)
        self._cellPadding = cellPadding
        self._cellShape = cellShape
        self._cellTransparency = cellTransparency
        self._cellBleed = cellBleed
        self._cellBackground = cellBackground
        self._cellFactory = cellFactory
        self._cells = []
        self._buffer = [UInt8](repeating: 0, count: self._displayWidth * self._displayHeight * Screen.depth)
        self._bufferBlocks = Cells.createBufferBlocks(bufferSize: self._buffer.count,
                                                      displayWidth: self._displayWidth,
                                                      displayHeight: self._displayHeight,
                                                      cellSize: self._cellSize,
                                                      cellPadding: self._cellPadding,
                                                      cellShape: self._cellShape,
                                                      cellTransparency: self._cellTransparency)
        for y in 0..<self.nrows {
            for x in 0..<self.ncolumns {
                self.defineCell(x: x, y: y, foreground: cellForeground, background: self._cellBackground)
            }
        }
    }

    var cells: [Cell] {
        self._cells
    }

    // Returns the cell coordinate for the given display input coordinates,
    // which (the display input coordinates) are always in unscaled units.
    //
    public func locate(_ screenPoint: CGPoint) -> CellGridPoint? {
        let point: CellGridPoint = CellGridPoint(screenPoint)
        if ((point.x < 0) || (point.y < 0) ||
            (point.x >= self._displayWidthUnscaled) || (point.y >= self._displayHeightUnscaled)) {
            return nil
        }
        return CellGridPoint(point.x / self._cellSizeUnscaled, point.y / self._cellSizeUnscaled)
    }

    public func cell<T: Cell>(_ screenPoint: CGPoint) -> T? {
        if let clocation: CellGridPoint = self.locate(screenPoint) {
            return self.cell(clocation.x, clocation.y)
        }
        return nil
    }

    public func cell<T: Cell>(_ x: Int, _ y: Int) -> T? {
        guard x >= 0, y >= 0, x < self.ncolumns, y < self.nrows else {
            return nil
        }
        return self._cells[y * self.ncolumns + x] as? T
    }

    var ncolumns: Int {
        self._displayWidth / self._cellSize
    }

    var nrows: Int {
        self._displayHeight / self._cellSize
    }

    public func fill(_ color: CellColor) {
        self.fill(color.color)
    }

    public func fill(_ color: Color) {
        let pixel: CellColor = CellColor(color)
        let count: Int = self._buffer.count / Screen.depth
        self._buffer.withUnsafeMutableBytes { raw in
            guard let buffer = raw.baseAddress else { return }
            Memory.fastcopy(to: buffer, count: count, value: pixel.value)
        }
    }

    func writeCell(x: Int, y: Int,
                   shiftx: Int = 0, shifty: Int = 0,
                   foreground: CellColor, background: CellColor, limit: Bool = false,
                   truncateLeft: Bool = false, truncateRight: Bool = false) {
        self.writeCell(buffer: &self._buffer, x: x, y: y,
                       shiftx: shiftx, shifty: shifty,
                       foreground: foreground, background: background, limit: limit,
                       truncateLeft: truncateLeft, truncateRight: truncateRight)
    }

    private func writeCell(buffer: inout [UInt8],
                          x: Int, y: Int,
                          shiftx: Int = 0, shifty: Int = 0,
                          foreground: CellColor, background: CellColor, limit: Bool = false,
                          truncateLeft: Bool = false, truncateRight: Bool = false)
    {
        // TODO: guard ...
        // TODO: special case for foreground == background - just write/fill square

        let offset: Int = ((self._cellSize * x) + shiftx + (self._cellSize * self._displayWidth * y + shifty * self._displayWidth)) * Screen.depth
        let size: Int = buffer.count

        buffer.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            for block in self._bufferBlocks.blocks {
                writeCellBlock(buffer: base, block: block)
            }
        }

        // Writes the given buffer block to the backing image (pixel value) buffer; each block describing a
        // range of indices and whether the block is for a foreground or background color, and the amount
        // it should be blended with the background if it is for a foreground color).
        // N.B. From the outer function scope: offset, size, foreground, background, limit
        //
        func writeCellBlock(buffer: UnsafeMutableRawPointer, block: BufferBlock)  {
            let start: Int = offset + block.index
            guard start >= 0, (start + (block.count * Memory.bufferBlockSize)) <= size else {
                return
            }
            let base = buffer.advanced(by: start)
            var color: CellColor
            if (block.foreground) {
                if (block.blend != 0.0) {
                    color = CellColor(Cells.blend(foreground.red,   background.red,   amount: block.blend),
                                      Cells.blend(foreground.green, background.green, amount: block.blend),
                                      Cells.blend(foreground.blue,  background.blue,  amount: block.blend),
                                      alpha: foreground.alpha)
                }
                else {
                    color = foreground
                }
            }
            else if (limit) {
                //
                // Limit the write to only the foreground; can be useful
                // for performance as background normally doesn't change.
                //
                return
            }
            else {
                color = background
            }
            Memory.fastcopy(to: base, count: block.count, value: color.value)
        }
    }

    private static func writeCell(buffer: inout [UInt8],
                                  cellSize: Int, // self._cellSize - scaled
                                  cellBlocks: [BufferBlock],
                                  cellX: Int,
                                  cellY: Int, // cell-relative position - (0, 0) top-left thru (viewWidth / cellSize - 1, viewHeight / cellSize - 1)
                                  cellForeground: CellColor,
                                  cellBackground: CellColor,
                                  cellForegroundOnly: Bool,
                                  shiftX: Int = 0,
                                  shiftY: Int = 0, // scaled
                                  viewWidth: Int, // self._displayWidth - scaled
                                  viewHeight: Int) // self._displayHeight - scaled (not used here i dont think)
    {
        let offset: Int = ((cellSize * cellX) + shiftX + (cellSize * viewWidth * cellY + shiftY * viewWidth)) * Screen.depth
        let size: Int = buffer.count

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

        buffer.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            for block in cellBlocks {
                //
                // TODO: Horizontal shift handling.
                //
                writeCellBlock(buffer: base, block: block)
            }
        }

        // Writes the given buffer block to the backing image (pixel value) buffer; each block describing a
        // range of indices and whether the block is for a foreground or background color, and the amount
        // it should be blended with the background if it is for a foreground color).
        // N.B. From the outer function scope: offset, size, cellForeground
        //
        func writeCellBlock(buffer: UnsafeMutableRawPointer, block: BufferBlock) {
            let start: Int = offset + block.index
            guard start >= 0, (start + (block.count * Memory.bufferBlockSize)) <= size else {
                return
            }
            let base = buffer.advanced(by: start)
            var color: CellColor
            if (block.foreground) {
                if (block.blend != 0.0) {
                    color = CellColor(Cells.blend(cellForeground.red,   cellBackground.red,   amount: block.blend),
                                      Cells.blend(cellForeground.green, cellBackground.green, amount: block.blend),
                                      Cells.blend(cellForeground.blue,  cellBackground.blue,  amount: block.blend),
                                      alpha: cellForeground.alpha)
                }
                else {
                    color = cellForeground
                }
            }
            else if (cellForegroundOnly) {
                //
                // Limit the write to only the foreground; can be useful
                // for performance as background normally doesn't change.
                //
                return
            }
            else {
                color = cellBackground
            }
            Memory.fastcopy(to: base, count: block.count, value: color.value)
        }
    }

    public var image: CGImage? {
        var image: CGImage?
        self._buffer.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                fatalError("Buffer has no base address")
            }
            if let context = CGContext(
                data: baseAddress,
                width: self._displayWidth,
                height: self._displayHeight,
                bitsPerComponent: 8,
                bytesPerRow: self._displayWidth * Screen.depth,
                space: CellGrid.Defaults.colorSpace,
                bitmapInfo: CellGrid.Defaults.bitmapInfo
            ) {
                image = context.makeImage()
            }
        }
        return image
    }

    private func defineCell(x: Int, y: Int, foreground: CellColor, background: CellColor) {
        let cell: Cell = (self._cellFactory != nil)
                         ? self._cellFactory!(self, x, y, foreground, background)
                         : Cell(parent: self, x: x, y: y, foreground: foreground, background: background)
        self._cells.append(cell)
    }

    private static func createBufferBlocks(bufferSize: Int,
                                           displayWidth: Int,
                                           displayHeight: Int,
                                           cellSize: Int,
                                           cellPadding: Int,
                                           cellShape: CellShape,
                                           cellTransparency: UInt8) -> BufferBlocks
    {
        let bufferBlocks: BufferBlocks = BufferBlocks()

        var cellPaddingThickness: Int = 0
        if ((cellPadding > 0) && (cellSize >= 6) && (cellShape != .square)) {
            cellPaddingThickness = cellPadding
        }

        let cellSizeAdjusted = cellSize - (2 * cellPaddingThickness)
        let fadeRange: Float = 0.6 // smaller is smoother

        for dy in 0..<cellSize {
            for dx in 0..<cellSize {

                if dx >= displayWidth || dy >= displayHeight { continue }
                if dx < 0 || dy < 0 { continue }
                let fx: Float = Float(dx) + 0.5
                let fy: Float = Float(dy) + 0.5
                var coverage: Float = 0.0

                switch cellShape {
                case .square, .inset:
                    if ((dx >= cellPaddingThickness) && (dx < cellSize - cellPaddingThickness) &&
                        (dy >= cellPaddingThickness) && (dy < cellSize - cellPaddingThickness)) {
                        coverage = 1.0
                    }

                case .circle:
                    let centerX: Float = Float(cellSize / 2)
                    let centerY: Float = Float(cellSize / 2)
                    let dxsq: Float = (fx - centerX) * (fx - centerX)
                    let dysq: Float = (fy - centerY) * (fy - centerY)
                    let dist: Float = sqrt(dxsq + dysq)
                    let circleRadius: Float = Float(cellSizeAdjusted) / 2.0
                    let d: Float = circleRadius - dist
                    coverage = max(0.0, min(1.0, d / fadeRange))

                case .rounded:
                    let cornerRadius: Float = Float(cellSizeAdjusted) * 0.25
                    let cr2: Float = cornerRadius * cornerRadius
                    let minX: Float = Float(cellPaddingThickness)
                    let minY: Float = Float(cellPaddingThickness)
                    let maxX: Float = Float(cellSize - cellPaddingThickness)
                    let maxY: Float = Float(cellSize - cellPaddingThickness)
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
                        let dist: Float = sqrt(dx * dx + dy * dy)
                        let d: Float = cornerRadius - dist
                        coverage = max(0.0, min(1.0, d / fadeRange))
                    }
                }

                let i: Int = (dy * displayWidth + dx) * Screen.depth
                if ((i >= 0) && ((i + (Screen.depth - 1)) < bufferSize)) {
                    if (coverage > 0) {
                        bufferBlocks.append(index: i, foreground: true, blend: coverage)

                    } else {
                        bufferBlocks.append(index: i, foreground: false)
                    }
                }
            }
        }

        return bufferBlocks
    }

    public static func blend(_ a: UInt8, _ b: UInt8, amount: Float) -> UInt8 {
        return UInt8(Float(a) * amount + Float(b) * (1 - amount))
    }

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
