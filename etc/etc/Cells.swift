import Foundation
import SwiftUI

// A main purpose of this (as first created) is for keeping track of the backing pixel buffer
// indices for the (canonical) cell; for the purpose of being able to write the values very fast
// using block memory copy (see Memory.fastcopy). It is ASSUMED that the addBufferItem function is
// called with indices which are monotonically increasing, and are not duplicated or out of order
// or anything weird; assume called from the buffer setting loop in the PixelMap._write method.
//
class Cells {

    class BufferBlock {
        var index: Int
        var foreground: Bool
        var blend: Float
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

    private var _displayWidth: Int // let
    private var _displayHeight: Int // let
    private let _displayScale: CGFloat
    private let _displayScaling: Bool
    private var _displayOrientation: UIDeviceOrientation = UIDevice.current.orientation
    private let _cellSize: Int
    private var _displayWidthUnscaled: Int // let
    private var _displayHeightUnscaled: Int // let
    private let _cellSizeUnscaled: Int
    private var _cellBufferBlocks: [BufferBlock] = []
    private var _cells: [Cell] = []
    public static let null: Cells = Cells(displayWidth: 0, displayHeight: 0, displayScale: 0.0, displayScaling: false, cellSize: 0)

    func rotateRight() {
        var cells: [Cell] = []
        for cell in self._cells {
            cells.append(Cell(x: cell.y, y: self.cellWidth - 1 - cell.x, parent: self))
        }
        self._cells = cells
        swap(&self._displayWidth, &self._displayHeight)
        swap(&self._displayWidthUnscaled, &self._displayHeightUnscaled)
    }

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

    var cells: [Cell] {
        self._cells
    }

    var caching: Bool {
        self._cellBufferBlocks.count > 0
    }

    var displayOrientation: UIDeviceOrientation {
        get { self._displayOrientation }
        set { self._displayOrientation = newValue }
    }

    // Returns the cell coordinate for the given display input coordinates,
    // which (the display input coordinates) are always in unscaled units.
    //
    public func locate(_ screenPoint: CGPoint) -> Point? {
        let point = Point(screenPoint)
        print("LOCATE: \(screenPoint) -> point: (\(point.x), \(point.y))")
        if (self._displayOrientation == .landscapeRight) {
            // let xscreenPoint = CGPoint(x: screenPoint.y, y: CGFloat(self._displayWidth) - screenPoint.x)
            let xscreenPoint = CGPoint(x: screenPoint.y, y: CGFloat(self._displayWidth + (self._displayWidth / 2)) - screenPoint.x)
            let xpoint = Point(xscreenPoint)
            print("LOCATE-LANDSCAPE-RIGHT-DISPLAY: \(self._displayWidth) x \(self._displayHeight) | unscaled: \(self._displayWidthUnscaled) x \(self._displayHeightUnscaled) ")
            print("LOCATE-LANDSCAPE-RIGHT: \(screenPoint) -> \(xscreenPoint) | (\(point.x),\(point.y)) -> (\(xpoint.x),\(xpoint.y))")
            if ((xpoint.x < 0) || (xpoint.y < 0) ||
                (xpoint.x >= self._displayWidthUnscaled) || (xpoint.y >= self._displayHeightUnscaled)) {
                print("LOCATE-LANDSCAPE-RIGHT: NIL")
                return nil
            }
            print("LOCATE-LANDSCAPE-RIGHT-END: \(xpoint.x / self._cellSizeUnscaled) \(xpoint.y / self._cellSizeUnscaled)")
            return Point(xpoint.x / self._cellSizeUnscaled, xpoint.y / self._cellSizeUnscaled)
            /*
            let x = point.y
            let y = self._displayHeightUnscaled - point.x
            print("LOCATE-LANDSCAPE-RIGHT: \(point.x) \(point.y) -> \(x) \(y)")
            if ((x < 0) || (y < 0) ||
                (x >= self._displayWidthUnscaled) || (y >= self._displayHeightUnscaled)) {
                print("LOCATE-LANDSCAPE-RIGHT: NIL")
                return nil
            }
            print("LOCATE-LANDSCAPE-RIGHT-END: \(x / self._cellSizeUnscaled) \(y / self._cellSizeUnscaled)")
            return Point(x / self._cellSizeUnscaled, y / self._cellSizeUnscaled)
            */
        }
        else {
            if ((point.x < 0) || (point.y < 0) ||
                (point.x >= self._displayWidthUnscaled) || (point.y >= self._displayHeightUnscaled)) {
                return nil
            }
            return Point(point.x / self._cellSizeUnscaled, point.y / self._cellSizeUnscaled)
        }
    }

    public func cell(_ screenPoint: CGPoint) -> Cell? {
        if let clocation = self.locate(screenPoint) {
            print("LOCATE-CELL: \(screenPoint) -> cell: (\(clocation.x), \(clocation.y))")
            return self.cell(clocation.x, clocation.y)
        }
        return nil
    }

    public func cell(_ x: Int, _ y: Int) -> Cell? {
        for cell in self._cells { // TODO: array-of-array is probably better here
            if ((cell.x == x) && (cell.y == y)) {
                return cell
            }
        }
        return nil
    }

    var cellWidth: Int {
        self._displayWidth / self._cellSize
    }

    var cellHeight: Int {
        self._displayHeight / self._cellSize
    }

    func defineCell(x: Int, y: Int) -> Cell {
        let cell: Cell = Cell(x: x, y: y, parent: self)
        self._cells.append(cell)
        return cell
    }

    func addBufferItem(_ index: Int, foreground: Bool, blend: Float = 0.0) {
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

    public static func blend(_ a: UInt8, _ b: UInt8, amount: Float) -> UInt8 {
        return UInt8(Float(a) * amount + Float(b) * (1 - amount))
    }

    public static func preferredCellSizes(_ displayWidth: Int,
                                          _ displayHeight: Int,
                                          displaySizeVariationMax: Int = 25) -> [(cellSize: Int,
                                                                                  displayWidth: Int,
                                                                                  displayHeight: Int)] {
        let minDimension = min(displayWidth, displayHeight)
        guard minDimension > 0 else { return [] }
        var results: [(cellSize: Int, displayWidth: Int, displayHeight: Int)] = []
        for cellSize in 1...minDimension {
            let cellsX = displayWidth / cellSize
            let cellsY = displayHeight / cellSize
            let usedW = cellsX * cellSize
            let usedH = cellsY * cellSize
            let leftX = displayWidth - usedW
            let leftY = displayHeight - usedH
            if ((leftX <= displaySizeVariationMax) && (leftY <= displaySizeVariationMax)) {
                let marginX: Int = leftX / 2
                let marginY: Int = leftY / 2
                results.append((cellSize: cellSize,
                                displayWidth: displayWidth - (marginX * 2),
                                displayHeight: displayHeight - (marginY * 2)))
            }
        }
        return results
    }

    public static func closestPreferredCellSize(in list: [(cellSize: Int, displayWidth: Int, displayHeight: Int)],
                                                to target: Int) -> (cellSize: Int, displayWidth: Int, displayHeight: Int)? {
        return list.min(by: {
            let a = abs($0.cellSize - target)
            let b = abs($1.cellSize - target)
            return (a, $0.cellSize) < (b, $1.cellSize)
        })
    }
}
