import Foundation
import SwiftUI

    struct Point {

        public let x: Int
        public let y: Int

        init(_ x: Int, _ y: Int) {
            self.x = x
            self.y = y
        }

        init(_ point: CGPoint) {
            self.x = Int(round(point.x))
            self.y = Int(round(point.y))
        }
    }

    struct Cells {

        class BufferBlock {
            var foreground: Bool
            var blend: Float
            var index: Int
            var count: Int
            var lindex: Int
            init(index: Int, count: Int, lindex: Int, foreground: Bool = true, blend: Float = 0.0) {
                self.index = index
                self.count = count
                self.foreground = foreground
                self.blend = blend
                self.lindex = lindex
            }
        }

        let _displayWidth: Int
        let _displayHeight: Int
        let _displayScale: CGFloat
        let _displayScaling: Bool
        let _cellSize: Int
        let _displayWidthUnscaled: Int
        let _displayHeightUnscaled: Int
        let _cellSizeUnscaled: Int
        var _cellBufferBlocks: [BufferBlock] = []
        var _cells: [Cell] = []

        init(displayWidth: Int, displayHeight: Int, displayScale: CGFloat, displayScaling: Bool, cellSize: Int) {

            func unscaled(_ value: Int) -> Int {
                return displayScaling ? Int(round(CGFloat(value) / displayScale)) : value
            }

            self._displayWidth = displayWidth
            self._displayHeight = displayHeight
            self._displayScale = displayScale
            self._displayScaling = displayScaling
            self._cellSize = cellSize
            self._displayWidthUnscaled = unscaled(displayWidth)
            self._displayHeightUnscaled = unscaled(displayHeight)
            self._cellSizeUnscaled = unscaled(cellSize)
        }

        // Returns the cell coordinate for the given display input coordinates,
        // which (the display input coordinates) are always in unscaled units.
        //
        public func locate(_ screenPoint: CGPoint) -> Point? {
            let point = Point(screenPoint)
            if ((point.x < 0) || (point.y < 0) ||
                (point.x >= self._displayWidthUnscaled) || (point.y >= self._displayHeightUnscaled)) { // should indeed be >= not > right?
                return nil
            }
            return Point(point.x / self._cellSizeUnscaled, point.y / self._cellSizeUnscaled)
        }

        public func cell(_ x: Int, _ y: Int) -> Cell? {
            for cell in self._cells {
                if ((cell.x == x) && (cell.y == y)) {
                    return cell
                }
            }
            return nil
        }

        mutating func addBufferItem(_ index: Int, foreground: Bool, blend: Float = 0.0) {
            if let last = self._cellBufferBlocks.last, last.foreground == foreground, last.blend == blend,
                          index == last.lindex + Memory.bufferBlockSize {
                last.count += 1
                last.lindex = index
            } else {
                self._cellBufferBlocks.append(BufferBlock(index: index, count: 1, lindex: index, foreground: foreground, blend: blend))
            }
        }

        public func write(_ buffer: inout [UInt8], x: Int, y: Int, foreground: PixelValue, background: PixelValue, limit: Bool = false) {
            let offset: Int = ((self._cellSize * x) + (self._cellSize * self._displayWidth * y)) * ScreenInfo.depth
            buffer.withUnsafeMutableBytes { raw in
                for block in self._cellBufferBlocks {
                    let base: UnsafeMutableRawPointer = raw.baseAddress!.advanced(by: block.index + offset)
                    var color: PixelValue = PixelValue.black
                    if (block.foreground) {
                        if (block.blend != 0.0) {
                            color = PixelValue(Cells.blend(foreground.red,   background.red,   amount: block.blend),
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

        private static func blend(_ a: UInt8, _ b: UInt8, amount: Float) -> UInt8 {
            return UInt8(Float(a) * amount + Float(b) * (1 - amount))
        }

        public mutating func defineCell(x: Int, y: Int) -> Cell {
            let cell: Cell = Cell(x: x, y: y, parent: self)
            self._cells.append(cell)
            return cell
        }
    }

    // This is mainly (was first created) for keeping track of the foreground/background buffer
    // indices for each cell, for the purpose of being able to write the values very fast using
    // block memory copy (see Memory.fastcopy). It is ASSUMED that the addBufferItem function is
    // called with indices which are monotonically increasing, and are not duplicated or out of order
    // or anything weird; assume called from the buffer setting loop in the PixelMap._write method.
    //
    struct Cell {

        let x: Int
        let y: Int
        var parent: Cells

        init(x: Int, y: Int, parent: Cells) {
            self.x = x
            self.y = y
            self.parent = parent
        }

        public mutating func addBufferItem(_ index: Int, foreground: Bool, blend: Float = 0.0) {
            parent.addBufferItem(index, foreground: foreground, blend: blend)
        }

        public func write(_ buffer: inout [UInt8], foreground: PixelValue, background: PixelValue, limit: Bool = false) {
            parent.write(&buffer, x: self.x, y: self.y, foreground: foreground, background: background, limit: limit)
        }
    }
