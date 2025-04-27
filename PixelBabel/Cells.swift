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
    typealias CellFactory = (_ parent: Cells, _ x: Int, _ y: Int) -> Cell
    typealias CellPreferredSize = (cellSize: Int, displayWidth: Int, displayHeight: Int)

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
    private let _cellFactory: CellFactory?
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
         cellFactory: CellFactory? = nil) {

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
        self._cellFactory = cellFactory
        self._cells = []
        self._buffer = [UInt8](repeating: 0, count: self._displayWidth * self._displayHeight * ScreenInfo.depth)
        self._bufferBlocks = Cells.createBufferBlocks(bufferSize: self._buffer.count,
                                                      displayWidth: self._displayWidth,
                                                      displayHeight: self._displayHeight,
                                                      cellSize: self._cellSize,
                                                      cellPadding: self._cellPadding,
                                                      cellShape: self._cellShape,
                                                      cellTransparency: self._cellTransparency)
        for y in 0..<self.nrows {
            for x in 0..<self.ncolumns {
                self.defineCell(x: x, y: y)
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

    public func cell(_ screenPoint: CGPoint) -> Cell? {
        if let clocation = self.locate(screenPoint) {
            return self.cell(clocation.x, clocation.y)
        }
        return nil
    }

    public func cell(_ x: Int, _ y: Int) -> Cell? {
        guard x >= 0, y >= 0, x < self.ncolumns, y < self.nrows else {
            return nil
        }
        return self._cells[y * self.ncolumns + x]
    }

    private var ncolumns: Int {
        self._displayWidth / self._cellSize
    }

    private var nrows: Int {
        self._displayHeight / self._cellSize
    }

    private func defineCell(x: Int, y: Int) {
        let cell: Cell = (self._cellFactory != nil) ? self._cellFactory!(self, x, y) : Cell(parent: self, x: x, y: y)
        self._cells.append(cell)
    }

    public func writeCell(x: Int, y: Int, foreground: CellColor, background: CellColor, limit: Bool = false) {
        self.writeCell(buffer: &self._buffer, x: x, y: y, foreground: foreground, background: background, limit: limit)
    }

    public func writeCell(buffer: inout [UInt8], x: Int, y: Int, foreground: CellColor, background: CellColor, limit: Bool = false) {
        let offset: Int = ((self._cellSize * x) + (self._cellSize * self._displayWidth * y)) * ScreenInfo.depth
        buffer.withUnsafeMutableBytes { raw in
            for block in self._bufferBlocks.blocks {
                let base: UnsafeMutableRawPointer = raw.baseAddress!.advanced(by: block.index + offset)
                var color: CellColor = CellColor.black
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
                    continue
                }
                else {
                    color = background
                }
                Memory.fastcopy(to: base, count: block.count, value: color.value)
            }
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
                bytesPerRow: self._displayWidth * ScreenInfo.depth,
                space: CellGrid.Defaults.colorSpace,
                bitmapInfo: CellGrid.Defaults.bitmapInfo
            ) {
                let start = CFAbsoluteTimeGetCurrent()
                image = context.makeImage()
                let end = CFAbsoluteTimeGetCurrent()
                print(String(format: "MAKE-IMAGE-TIME: %.5f ms | \(image!.width) \(image!.height)", (end - start) * 1000))
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

                let i = (iy * displayWidth + ix) * ScreenInfo.depth
                if ((i >= 0) && ((i + 3) < bufferSize)) {
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

    public static func preferredCellSizes(_ displayWidth: Int,
                                          _ displayHeight: Int,
                                          cellPreferredSizeMarginMax: Int = CellGrid.Defaults.cellPreferredSizeMarginMax)
                                          -> [CellPreferredSize] {
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
                let marginx: Int = leftx / 2
                let marginy: Int = lefty / 2
                results.append((cellSize: cellSize,
                                displayWidth: displayWidth - (marginx * 2),
                                displayHeight: displayHeight - (marginy * 2)))
            }
        }
        return results
    }

    public static func closestPreferredCellSize(in list: [CellPreferredSize], to target: Int) -> CellPreferredSize? {
        return list.min(by: {
            let a = abs($0.cellSize - target)
            let b = abs($1.cellSize - target)
            return (a, $0.cellSize) < (b, $1.cellSize)
        })
    }
}
