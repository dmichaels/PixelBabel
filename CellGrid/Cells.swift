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

        func dump(verbose: Bool = false) {
            if verbose {
                for i in 0..<self.count {
                    print("BLOCK>" +
                          " INDEX: \(String(format: "%8d", self.index + i * 4))" +
                          "  \(self.foreground ? "FG" : "BG")-\(String(format: "%.1f", self.blend))" +
                          " \(i == 0 ? "B: \(String(format: "%3d", self.count))" : "C")")
                }
            }
            else {
                print("block>" +
                      " index: \(String(format: "%8d", self.index))" +
                      " count: \(String(format: "%3d", self.count))" +
                      "  \(self.foreground ? "FG" : "BG")-\(String(format: "%.1f", self.blend))")
            }
        }
    }

    private class BufferBlocks {

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

        static func prune(_ block: BufferBlock, offset: Int, width: Int, shiftx: Int) -> [BufferBlock] {
            let stride = 4
            var results: [BufferBlock] = []
            var currentBlockStart: Int? = nil
            var currentBlockCount = 0
            for i in 0..<block.count {
                let chunkStart = offset + block.index + i * stride
                if (((shiftx > 0) && (((chunkStart / 4) % width) >= shiftx)) ||
                    ((shiftx < 0) && ((chunkStart / 4) % width) < -shiftx)) {
                    if currentBlockStart == nil {
                        currentBlockStart = chunkStart
                        currentBlockCount = 1
                    } else {
                        currentBlockCount += 1
                    }
                } else {
                    if let start = currentBlockStart {
                        results.append(BufferBlock(index: start - offset, count: currentBlockCount, foreground: block.foreground, blend: block.blend))
                        currentBlockStart = nil
                        currentBlockCount = 0
                    }
                }
            }
            if let start = currentBlockStart {
                results.append(BufferBlock(index: start - offset, count: currentBlockCount, foreground: block.foreground, blend: block.blend))
            }
            return results
        }
    }

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

    init(displayWidth: Int,
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

        func unscaled(_ value: Int) -> Int {
            return displayScaling ? Int(round(CGFloat(value) / displayScale)) : value
        }

        self._displayWidth = displayWidth
        self._displayHeight = displayHeight
        self._displayWidthUnscaled = unscaled(displayWidth)
        self._displayHeightUnscaled = unscaled(displayHeight)
        self._displayScale = displayScale
        self._displayScaling = displayScaling
        self._cellSize = cellSize
        self._cellSizeUnscaled = unscaled(cellSize)
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

    public func fill(_ color: CellColor) {
        self.fill(color.color)
    }

    public func fill(_ color: Color) {
        let pixel: CellColor = CellColor(color)
        let count = self._buffer.count / Screen.depth
        self._buffer.withUnsafeMutableBytes { raw in
            guard let buffer = raw.baseAddress else { return }
            Memory.fastcopy(to: buffer, count: count, value: pixel.value)
        }
    }

    var cells: [Cell] {
        self._cells
    }

    // Returns the cell coordinate for the given display input coordinates,
    // which (the display input coordinates) are always in unscaled units.
    //
    public func locate(_ screenPoint: CGPoint) -> CellGridPoint? {
        let point = CellGridPoint(screenPoint)
        if ((point.x < 0) || (point.y < 0) ||
            (point.x >= self._displayWidthUnscaled) || (point.y >= self._displayHeightUnscaled)) {
            return nil
        }
        return CellGridPoint(point.x / self._cellSizeUnscaled, point.y / self._cellSizeUnscaled)
    }

    public func cell<T: Cell>(_ screenPoint: CGPoint) -> T? {
        if let clocation = self.locate(screenPoint) {
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

    private func defineCell(x: Int, y: Int, foreground: CellColor, background: CellColor) {
        let cell: Cell = (self._cellFactory != nil)
                         ? self._cellFactory!(self, x, y, foreground, background)
                         : Cell(parent: self, x: x, y: y, foreground: foreground, background: background)
        self._cells.append(cell)
    }

    public func writeCell(x: Int, y: Int, foreground: CellColor, background: CellColor, limit: Bool = false) {
        self.writeCell(buffer: &self._buffer, x: x, y: y, foreground: foreground, background: background, limit: limit)
    }

    public func writeCell(buffer: inout [UInt8],
                          x: Int, y: Int,
                          foreground: CellColor,
                          background: CellColor,
                          limit: Bool = false,
                          shiftx: Int = 0,
                          shifty: Int = 0) {

        func scaled(_ value: Int) -> Int {
            CellGrid.Defaults.displayScaling ? Int(round(CGFloat(value) * CGFloat(3.0))) : value
        }

        let shiftX: Int = scaled(25)
        let shiftY: Int = scaled(25)
        let offset: Int = ((self._cellSize * x) + shiftX + (self._cellSize * self._displayWidth * y + shiftY * self._displayWidth)) * Screen.depth
        let size: Int = buffer.count

        // Cheat sheet on shifting right (shiftx > 0); shifting vertically just falls out,
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
        //     | V | W | X | c | f | g | 4
        //     +---+---+---+---+---+---+
        //     | Y | Z | a | h | i | j | 5
        //     +---+---+---+---+---+---+
        //       ^   ^ 
        //       |   |
        //       -   -
        // If we want to ignore these (say) 2 left-most columns (s) due to right shift,
        // then we want to ignore (i.e. not write) buffer indices (I) where: I % W < S ...
        //
        //      0: A -> I % W ==  0 % 6 == 0 <<< ignore: A
        //      1: B -> I % W ==  1 % 6 == 1 <<< ignore: B
        //      2: C -> I % W ==  2 % 6 == 2
        //      3: J -> I % W ==  3 % 6 == 3
        //      4: K -> I % W ==  4 % 6 == 4
        //      5: L -> I % W ==  5 % 6 == 5
        //      6: D -> I % W ==  6 % 6 == 0 <<< ignore: D
        //      7: E -> I % W ==  7 % 6 == 1 <<< ignore: E
        //      8: F -> I % W ==  8 % 6 == 2
        //      9: M -> I % W ==  9 % 6 == 3
        //     10: N -> I % W == 10 % 6 == 4
        //     11: O -> I % W == 11 % 6 == 5
        //     12: G -> I % W == 12 % 6 == 0 <<< ignore: G
        //     13: H -> I % W == 13 % 6 == 1 <<< ignore: H
        //     14: I -> I % W == 14 % 6 == 2
        //     15: P -> I % W == 15 % 6 == 3
        //     16: Q -> I % W == 16 % 6 == 4
        //     17: R -> I % W == 17 % 6 == 5
        //     18: S -> I % W == 18 % 6 == 0 <<< ignore: S
        //     19: T -> I % W == 19 % 6 == 1 <<< ignore: T
        //     20: U -> I % W == 20 % 6 == 2
        //     21: b -> I % W == 21 % 6 == 3
        //     22: c -> I % W == 22 % 6 == 4
        //     23: d -> I % W == 23 % 6 == 5
        //     24: V -> I % W == 24 % 6 == 0 <<< ignore: V
        //     25: W -> I % W == 25 % 6 == 1 <<< ignore: V
        //     26: X -> I % W == 26 % 6 == 2
        //     27: c -> I % W == 27 % 6 == 3
        //     28: f -> I % W == 28 % 6 == 4
        //     29: g -> I % W == 29 % 6 == 5
        //     30: Y -> I % W == 30 % 6 == 0 <<< ignore: Y
        //     31: Z -> I % W == 31 % 6 == 1 <<< ignore: Z
        //     32: a -> I % W == 32 % 6 == 2
        //     33: h -> I % W == 33 % 6 == 3
        //     34: i -> I % W == 34 % 6 == 4
        //     35: j -> I % W == 35 % 6 == 5
        //
        // Note that the BufferBlock.index is a byte index into the buffer,
        // i.e. it already has Screen.depth factored into it; and note that
        // the BufferBlock.count refers to the number of 4-byte (UInt32) values,

        buffer.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            for block in self._bufferBlocks.blocks {
                if ((shiftX > 0) && (x == 8) /* TODO */ ) {
                    for block in BufferBlocks.prune(block, offset: offset, width: self._displayWidth, shiftx: shiftX) {
                        writeCellBlock(buffer: base, block: block)
                    }
                    continue
                }
                else if ((shiftX < 0) && (x == 0) /* TODO */ ) {
                    for block in BufferBlocks.prune(block, offset: offset, width: self._displayWidth, shiftx: shiftX) {
                        writeCellBlock(buffer: base, block: block)
                    }
                    continue
                }
                writeCellBlock(buffer: base, block: block)
            }
        }

        func writeCellBlock(buffer: UnsafeMutableRawPointer, block: BufferBlock)  {
            let start: Int = offset + block.index
            guard start >= 0, (start + (block.count * Memory.bufferBlockSize)) <= size else { return }
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

    private static func createBufferBlocks(bufferSize: Int,
                                           displayWidth: Int,
                                           displayHeight: Int,
                                           cellSize: Int,
                                           cellPadding: Int,
                                           cellShape: CellShape,
                                           cellTransparency: UInt8) -> BufferBlocks
    {
        var bufferBlocks: BufferBlocks = BufferBlocks()

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
                let fx = Float(dx) + 0.5
                let fy = Float(dy) + 0.5
                var coverage: Float = 0.0

                switch cellShape {
                case .square, .inset:
                    if ((dx >= cellPaddingThickness) && (dx < cellSize - cellPaddingThickness) &&
                        (dy >= cellPaddingThickness) && (dy < cellSize - cellPaddingThickness)) {
                        coverage = 1.0
                    }

                case .circle:
                    let centerX = Float(cellSize / 2)
                    let centerY = Float(cellSize / 2)
                    let dxsq = (fx - centerX) * (fx - centerX)
                    let dysq = (fy - centerY) * (fy - centerY)
                    let dist = sqrt(dxsq + dysq)
                    let circleRadius = Float(cellSizeAdjusted) / 2.0
                    let d = circleRadius - dist
                    coverage = max(0.0, min(1.0, d / fadeRange))

                case .rounded:
                    let cornerRadius = Float(cellSizeAdjusted) * 0.25
                    let cr2 = cornerRadius * cornerRadius
                    let minX = Float(cellPaddingThickness)
                    let minY = Float(cellPaddingThickness)
                    let maxX = Float(cellSize - cellPaddingThickness)
                    let maxY = Float(cellSize - cellPaddingThickness)
                    if ((fx >= minX + cornerRadius) && (fx <= maxX - cornerRadius)) {
                        if fy >= minY && fy <= maxY {
                            coverage = 1.0
                        }
                    } else if ((fy >= minY + cornerRadius) && (fy <= maxY - cornerRadius)) {
                        if fx >= minX && fx <= maxX {
                            coverage = 1.0
                        }
                    } else {
                        let cx = fx < minX + cornerRadius ? minX + cornerRadius :
                                 fx > maxX - cornerRadius ? maxX - cornerRadius : fx
                        let cy = fy < minY + cornerRadius ? minY + cornerRadius :
                                 fy > maxY - cornerRadius ? maxY - cornerRadius : fy
                        let dx = fx - cx
                        let dy = fy - cy
                        let dist = sqrt(dx * dx + dy * dy)
                        let d = cornerRadius - dist
                        coverage = max(0.0, min(1.0, d / fadeRange))
                    }
                }

                let i = (dy * displayWidth + dx) * Screen.depth
                if ((i >= 0) && ((i + (Screen.depth - 1)) < bufferSize)) {
                    let alpha = UInt8(Float(cellTransparency) * coverage)
                    if coverage > 0 {
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
