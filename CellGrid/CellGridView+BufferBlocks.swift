//
//  CellGridView+BufferBlocks.swift
//  PixelBabel
//
//  Created by David Michaels on 5/16/25.
//

import Foundation
import SwiftUI
import Utils

extension CellGridView
{
    internal class BufferBlocks
    {
        internal class BufferBlock
        {
            internal let index: Int
            internal let foreground: Bool
            internal let blend: Float
            internal var count: Int
            internal var width: Int
            internal var indexLast: Int
            internal var shiftxCache: [Int: [(index: Int, count: Int)]] = [:]
            internal typealias WriteCellBlock = (_ block: BufferBlock, _ index: Int, _ count: Int) -> Void

            init(index: Int, count: Int, foreground: Bool, blend: Float, width: Int) {
                self.index = max(index, 0)
                self.count = max(count, 0)
                self.foreground = foreground
                self.blend = blend
                self.width = width
                self.indexLast = self.index
            }

            // Write blocks using the given write function IGNORING indices to the RIGHT of the given shiftx value.
            //
            internal func writeLeft(shiftx: Int, write: WriteCellBlock) {
                self.writeTruncated(shiftx: -shiftx, write: write)
            }

            // Write blocks using the given write function IGNORING indices to the LEFT Of the given shiftx value.
            //
            internal func writeRight(shiftx: Int, write: WriteCellBlock) {
                self.writeTruncated(shiftx: shiftx, write: write)
            }

            // Write blocks using the given write function IGNORING indices which correspond to
            // a shifting left or right by the given (shiftx) amount; tricky due to the row-major
            // organization of grid cells/pixels in the one-dimensional buffer array.
            //
            // A positive shiftx means to truncate the values (pixels) LEFT of the given shiftx value; and
            // a negative shiftx means to truncate the values (pixels) RIGHT of the given shiftx value; and
            //
            // Note that the BufferBlock.index is a byte index into the buffer, i.e. it already has Screen.depth
            // factored into it; and note that the BufferBlock.count refers to the number of 4-byte (UInt32) values,
            //
            internal func writeTruncated(shiftx: Int, write: WriteCellBlock) {

                if let shiftxValues = self.shiftxCache[shiftx] {
                    //
                    // Caching block values (index, count) distinct shiftx values can
                    // can really speed things up noticably (e.g. 0.02874s vs 0.07119s).
                    // FYI for really big cell-sizes (e.g. 250 unscaled) the size of this
                    // cache could exceed 25MB; not too bad really for the performance benefit.
                    // We could pre-populate this but it takes too longer (more than a second) for
                    // larger cell-sizes; it would look like this at the end of createBufferBlocks:
                    //
                    //  for shiftx in 1...(cellSize - 1) {
                    //    func dummyWriteCellBlock(_ block: BufferBlocks.BufferBlock, _ index: Int, _ count: Int) {}
                    //    for block in blocks._blocks {
                    //      block.writeTruncated(shiftx: shiftx, write: dummyWriteCellBlock, debug: false)
                    //      block.writeTruncated(shiftx: -shiftx, write: dummyWriteCellBlock, debug: false)
                    //    }
                    //  }
                    //
                    self.shiftxCache[shiftx]?.forEach { write(self, $0.index, $0.count) }
                    return
                }

                var shiftxValuesToCache: [(index: Int, count: Int)] = []
                let shiftw: Int = abs(shiftx)
                let shiftl: Bool = (shiftx < 0)
                let shiftr: Bool = (shiftx > 0)
                var index: Int? = nil
                var count: Int = 0
                for i in 0..<self.count {
                    let starti: Int = self.index + i * Memory.bufferBlockSize
                    let shift: Int = (starti / Memory.bufferBlockSize) % self.width
                    if ((shiftr && (shift >= shiftw)) || (shiftl && (shift < shiftw))) {
                        if (index == nil) {
                            index = starti
                            count = 1
                        } else {
                            count += 1
                        }
                    } else {
                        if let j: Int = index {
                            shiftxValuesToCache.append((index: j, count: count))
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
                if let j: Int = index {
                    shiftxValuesToCache.append((index: j, count: count))
                    write(self, j, count)
                }
                self.shiftxCache[shiftx] = shiftxValuesToCache
            }
        }

        private let _width: Int
        private var _blocks: [BufferBlock] = []

        init(width: Int) {
            self._width = width
        }

        internal var blocks: [BufferBlock] {
            self._blocks
        }

        internal var memoryUsageBytes: Int {
            let totalBlocks: Int = self._blocks.count
            var totalTuples: Int = 0
            for block in self._blocks {
                totalTuples += block.shiftxCache.values.reduce(0) { $0 + $1.count }
            }
            return totalTuples * MemoryLayout<(Int, Int)>.stride
        }

        private func append(_ index: Int, foreground: Bool, blend: Float, width: Int) {
            if let last: BufferBlock = self._blocks.last,
                   last.foreground == foreground,
                   last.blend == blend,
                   index == last.indexLast + Memory.bufferBlockSize {
                last.count += 1
                last.indexLast = index
            } else {
                self._blocks.append(BufferBlock(index: index, count: 1,
                                                foreground: foreground, blend: blend, width: width))
            }
        }

        internal static func createBufferBlocks(bufferSize: Int,
                                               viewWidth: Int,
                                               viewHeight: Int,
                                               cellSize: Int,
                                               cellPadding: Int,
                                               cellShape: CellShape,
                                               cellTransparency: UInt8) -> BufferBlocks
        {
            let blocks: BufferBlocks = BufferBlocks(width: viewWidth)
            let padding: Int = ((cellPadding > 0) && (cellShape != .square))
                               ? (((cellPadding * 2) >= cellSize)
                                 ? ((cellSize / 2) - 1)
                                 : cellPadding) : 0
            let cellSizeMinusPadding: Int = cellSize - padding
            let cellSizeMinusPaddingTimesTwo: Int = cellSize - (2 * padding)
            let shape: CellShape = (cellSizeMinusPaddingTimesTwo < 3) ? .inset : cellShape
            let fade: Float = Defaults.cellAntialiasFade

            for dy in 0..<cellSize {
                for dx in 0..<cellSize {
    
                    if ((dx >= viewWidth) || (dy >= viewHeight)) { continue }
                    if ((dx < 0) || (dy < 0)) { continue }
                    let coverage: Float

                    switch shape {
                    case .square, .inset:
                        if ((dx >= padding) && (dx < cellSizeMinusPadding) &&
                            (dy >= padding) && (dy < cellSizeMinusPadding)) {
                            coverage = 1.0
                        }
                        else { coverage = 0.0 }

                    case .circle:
                        let fx: Float = Float(dx) + 0.5
                        let fy: Float = Float(dy) + 0.5
                        let centerX: Float = Float(cellSize / 2)
                        let centerY: Float = Float(cellSize / 2)
                        let dxsq: Float = (fx - centerX) * (fx - centerX)
                        let dysq: Float = (fy - centerY) * (fy - centerY)
                        let circleRadius: Float = Float(cellSizeMinusPaddingTimesTwo) / 2.0
                        let d: Float = circleRadius - sqrt(dxsq + dysq)
                        coverage = max(0.0, min(1.0, d / fade))

                    case .rounded:
                        let fx: Float = Float(dx) + 0.5
                        let fy: Float = Float(dy) + 0.5
                        let cornerRadius: Float = Float(cellSizeMinusPaddingTimesTwo) * Defaults.cellRoundedRectangleRadius
                        let minX: Float = Float(padding)
                        let minY: Float = Float(padding)
                        let maxX: Float = Float(cellSizeMinusPadding)
                        let maxY: Float = Float(cellSizeMinusPadding)
                        if ((fx >= minX + cornerRadius) && (fx <= maxX - cornerRadius)) {
                            if ((fy >= minY) && (fy <= maxY)) { coverage = 1.0 }
                            else { coverage = 0.0 }
                        } else if ((fy >= minY + cornerRadius) && (fy <= maxY - cornerRadius)) {
                            if ((fx >= minX) && (fx <= maxX)) { coverage = 1.0 }
                            else { coverage = 0.0 }
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

                    let index: Int = (dy * viewWidth + dx) * Screen.depth
                    if ((index >= 0) && ((index + (Screen.depth - 1)) < bufferSize)) {
                        if (coverage > 0) {
                            blocks.append(index, foreground: true, blend: coverage, width: viewWidth)
    
                        } else {
                            blocks.append(index, foreground: false, blend: 0.0, width: viewWidth)
                        }
                    }
                }
            }

            return blocks
        }
    }
}
