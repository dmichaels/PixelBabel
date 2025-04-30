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

    private class BufferBlock {
        let index: Int
        let foreground: Bool
        let blend: Float
        var count: Int
        var lindex: Int
        init(index: Int, count: Int, foreground: Bool = true, blend: Float = 0.0) {
            self.index = index
            self.count = count
            self.foreground = foreground
            self.blend = blend
            self.lindex = index
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

public func nwriteCell(
    buffer: inout [UInt8],
    x: Int,
    y: Int,
    foreground: CellColor,
    background: CellColor,
    limit: Bool = false,
    shiftX: Int = 200, // Positive = right, negative = left
    shiftY: Int = 200  // Positive = down, negative = up
) {
    let bytesPerPixel = Screen.depth
    let bufferWidth = self._displayWidth
    let bufferHeight = self._displayHeight
    let bufferSize = buffer.count

    buffer.withUnsafeMutableBytes { raw in
        guard let baseAddress = raw.baseAddress else { return }

        for block in self._bufferBlocks.blocks {
            let originalIndex = block.index
            let blockStartX = (originalIndex / bytesPerPixel) % self._cellSize
            let blockStartY = (originalIndex / bytesPerPixel) / self._cellSize

            // Calculate absolute pixel position in the buffer
            let absX = x * self._cellSize + blockStartX + shiftX
            let absY = y * self._cellSize + blockStartY + shiftY

            // Skip this block if it's entirely off-screen
            if absX < 0 || absX + block.count > bufferWidth || absY < 0 || absY >= bufferHeight {
                continue
            }

            let pixelOffset = (absY * bufferWidth + absX) * bytesPerPixel
            if pixelOffset < 0 || pixelOffset + block.count * bytesPerPixel > bufferSize {
                continue
            }

            let base = baseAddress.advanced(by: pixelOffset)
            let color: CellColor

            if block.foreground {
                if block.blend != 0.0 {
                    color = CellColor(
                        Cells.blend(foreground.red, background.red, amount: block.blend),
                        Cells.blend(foreground.green, background.green, amount: block.blend),
                        Cells.blend(foreground.blue, background.blue, amount: block.blend),
                        alpha: foreground.alpha
                    )
                } else {
                    color = foreground
                }
            } else if limit {
                continue
            } else {
                color = background
            }

            Memory.fastcopy(to: base, count: block.count, value: color.value)
        }
    }
}

    public func writeCell(buffer: inout [UInt8], x: Int, y: Int, foreground: CellColor, background: CellColor, limit: Bool = false) {

        func scaled(_ value: Int) -> Int {
            CellGrid.Defaults.displayScaling ? Int(round(CGFloat(value) * CGFloat(3.0))) : value
        }

        // print("WRITE-CELL: [\(x), \(y)] | dw: \(self._displayWidth) | cs: \(self._cellSize) | color: \(foreground.hex)")
        var nskips = 0
        let size = buffer.count
        // let offset: Int = ((self._cellSize * x) + (self._cellSize * self._displayWidth * y)) * Screen.depth
        let shiftx = scaled(24)
        let shifty = 0 // (10 * 3)
        let offset = ((self._cellSize * x) + shiftx + (self._cellSize * self._displayWidth * y + shifty * self._displayWidth)) * Screen.depth
        var fg = foreground
        if x == 8 {
            fg = CellColor(Color.blue)
        }
        if x == 7 {
            fg = CellColor(Color.yellow)
        }
        buffer.withUnsafeMutableBytes { raw in
            guard let bufferAddress = raw.baseAddress else { return } // xyzzy
            var blockNumber = -1
            var blockFirstStart = 0
            for block in self._bufferBlocks.blocks {
                blockNumber += 1
                if blockNumber == 0 {
                    blockFirstStart = offset + block.index
                }
                //xyzzy
                var count = block.count
                var start = offset + block.index
                let nbytes = count * Memory.bufferBlockSize
                let end = start + nbytes
                //xyzzy
                /*
                if (y == 0) && ((x == 0) || (x == 7)) {
                    print("WRITE-CELL-BLOCK(\(x)): start: \(start) nbytes: \(nbytes) end: \(end) size: \(size) block-count: \(block.count)")
                }
                */
                //xyzzy2
                if ((shiftx > 0) && ((start - ((start / self._displayWidth) * self._displayWidth)) < shiftx)) {
                    // print("SKIP-ITEM: start: \(start) offset: \(offset) fg: \(foreground.hex) hm: \((start - ((start / self._displayWidth) * self._displayWidth))) | y: \(start / self._displayWidth))")
                    // start += shiftx
                    // count -= shiftx
                }
                //xyzzy2
                guard start >= 0, end <= size else {
                    nskips += 1
                    // print("⚠️ Skipping write: Out-of-bounds write attempt (\(start)..<\(end)), buffer size: \(size)")
                    continue
                }
                let base = bufferAddress.advanced(by: start)
                //xyzzy
                // xyzzy let base: UnsafeMutableRawPointer = raw.baseAddress!.advanced(by: block.index + offset) // xyzzy
                var color: CellColor
                if (block.foreground) {
                    if (block.blend != 0.0) {
                        color = CellColor(Cells.blend(fg.red,   background.red,   amount: block.blend),
                                          Cells.blend(fg.green, background.green, amount: block.blend),
                                          Cells.blend(fg.blue,  background.blue,  amount: block.blend),
                                          alpha: fg.alpha)
                    }
                    else {
                        color = fg
                    }
                }
                else if (limit) {
                    //
                    // Limit the write to only the foreground; can be useful
                    // for performance as background normally doesn't change.
                    //
                    continue
                }
                else {
                    color = background
                }
                /*
                if (((x == 0) || (x == 1) || (x == 2)) && ((y == 0) || (y == 1) || (y == 2))) {
                    let cw = self._displayWidth * self._cellSize * Screen.depth
                    let cy = start / cw
                    // let cx = start - (cy * cw)
                    // let cx = (start - (cy * cw)) / self._cellSize
                    // let cx = ((start - (cy * cw)) / self._cellSize) / 36 
                    // let cx = ((blockFirstStart - (cy * cw)) / self._cellSize) / 36 
                    // let cx = blockFirstStart - (cy * cw)
                    // let cx = (blockFirstStart - (cy * cw)) / 129 / 4
                    let cx = (blockFirstStart - (cy * cw)) / (self._cellSize * Screen.depth)
                    let cxs = ((offset + block.index) - (cy * cw))
                    print("WR: [\(x),\(y)] block: \(blockNumber) block-first-start: \(blockFirstStart) offset: \(offset) start: \(start) count: \(count) color: \(color.hex) cx: \(cx) cy: \(cy) | cxs: \(cxs)")
                }
                */

                if (x == 8) {
                    let cw = self._displayWidth * self._cellSize * Screen.depth
                    let cy = start / cw
                    let cx = (blockFirstStart - (cy * cw)) / (self._cellSize * Screen.depth)
                    let cxs = ((offset + block.index) - (cy * cw))
                    let t = start - (cy * cw)
                    if block.index == 0 {
                        // color = CellColor(Color.green)
                    }
                    print("WR: [\(x),\(y)] offset: \(offset) block: \(blockNumber) block-index: \(block.index) start: \(start) count: \(count) color: \(color.hex) cy: \(cy) | T: \(t)")
                    // print("WR: [\(x),\(y)] block: \(blockNumber) block-first-start: \(blockFirstStart) offset: \(offset) start: \(start) count: \(count) color: \(color.hex) cx: \(cx) cy: \(cy) | cxs: \(cxs)")
                }
                if x == 8 && block.index == 0 {
                    print("FOOY")

                    // let b = bufferAddress.advanced(by: start + 100)
                    // Memory.fastcopy(to: base, count: count - 69, value: CellColor(Color.green).value) // ok for shiftx = 24 * 3 with scaling = true
                    // Memory.fastcopy(to: base, count: count - 72, value: CellColor(Color.green).value) // ok for shiftx = 25 * 3 with scaling = true
                    // Memory.fastcopy(to: base, count: count - 27, value: CellColor(Color.green).value) // ok for shiftx = 10 * 3 with scaling = true
                    // Memory.fastcopy(to: base, count: count - 0, value: CellColor(Color.green).value) // ok for shiftx = 1 * 3 with scaling = true
                    // Memory.fastcopy(to: base, count: count - 117, value: CellColor(Color.green).value) // ok for shiftx = 40 * 3 with scaling = true
                    // Memory.fastcopy(to: base, count: count - 117, value: CellColor(Color.green).value) // ok for shiftx = 40 * 3 with scaling = true
                    // Memory.fastcopy(to: base, count: count - (shiftx - scaled(1)), value: CellColor(Color.green).value) // ok for shiftx = 40 * 3 with scaling = true
                    // Memory.fastcopy(to: base, count: count - (shiftx - scaled(1)), value: CellColor(Color.green).value) // ok for shiftx = 40 * 3 with scaling = true

                    // Memory.fastcopy(to: base, count: count - 69, value: CellColor(Color.green).value) // not ok at all for shiftx = 24 * 3 with scaling = false
                    // Memory.fastcopy(to: base, count: count - 2, value: CellColor(Color.green).value) // ok for shiftx = 1 * 3 with scaling = false
                    // Memory.fastcopy(to: base, count: count - (shiftx - scaled(1)), value: CellColor(Color.green).value) // ok for shiftx = 40 * 3 with scaling = false

                    // POST FIX PREFERRED SIZE TO RETURN USED-WH ...
                    // OK for shiftx =  1 with scaling = true
                    // OK for shiftx =  1 with scaling = false
                    // OK for shiftx = 24 with scaling = true
                    Memory.fastcopy(to: base, count: count - shiftx, value: CellColor(Color.green).value)
                }
                else {
                    Memory.fastcopy(to: base, count: count, value: color.value) // okay
                }
            }
        }
        // print("WRITE-CELL-DONE: [\(x), \(y)] | skips: \(nskips)")
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
                print("MADE-IMAGE: \(image!.width) x \(image!.height)")
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

        let endX = cellSize
        let endY = cellSize
        let cellSizeAdjusted = cellSize - (2 * cellPaddingThickness)
        let centerX = Float(cellSize / 2)
        let centerY = Float(cellSize / 2)
        let circleRadius = Float(cellSizeAdjusted) / 2.0
        let radiusSquared = circleRadius * circleRadius
        let fadeRange: Float = 0.6 // smaller is smoother

        for dy in 0..<cellSize {
            for dx in 0..<cellSize {

                let ix = dx
                let iy = dy
                if ix >= displayWidth || iy >= displayHeight { continue }
                if ix < 0 || iy < 0 { continue }
                let fx = Float(ix) + 0.5
                let fy = Float(iy) + 0.5
                var coverage: Float = 0.0

                switch cellShape {
                case .square, .inset:
                    if ((dx >= cellPaddingThickness) && (dx < cellSize - cellPaddingThickness) &&
                        (dy >= cellPaddingThickness) && (dy < cellSize - cellPaddingThickness)) {
                        coverage = 1.0
                    }

                case .circle:
                    let dxsq = (fx - centerX) * (fx - centerX)
                    let dysq = (fy - centerY) * (fy - centerY)
                    let dist = sqrt(dxsq + dysq)
                    let d = circleRadius - dist
                    coverage = max(0.0, min(1.0, d / fadeRange))

                case .rounded:
                    let cornerRadius = Float(cellSizeAdjusted) * 0.25
                    let cr2 = cornerRadius * cornerRadius
                    let minX = Float(cellPaddingThickness)
                    let minY = Float(cellPaddingThickness)
                    let maxX = Float(endX - cellPaddingThickness)
                    let maxY = Float(endY - cellPaddingThickness)
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

                let i = (iy * displayWidth + ix) * Screen.depth
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
                /*
                let marginx: Int = leftx / 2
                let marginy: Int = lefty / 2
                if cellSize == 43 {
                    print("DEBUG-PREF: margin-xy: \(marginx) \(marginy) left-xy: \(leftx) \(lefty) used-wh: \(usedw) \(usedh)")
                }
                results.append((cellSize: cellSize,
                                displayWidth: displayWidth - (marginx * 2),
                                displayHeight: displayHeight - (marginy * 2)))
                */
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
