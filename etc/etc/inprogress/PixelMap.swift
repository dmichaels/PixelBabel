import CoreGraphics
import Foundation
import SwiftUI

@MainActor
class PixelMap: ObservableObject {

    // This is mainly (was first created) for keeping track of the foreground/background buffer
    // indices for each cell, for the purpose of being able to write the values very fast using
    // block memory copy (see Memory.fastcopy). It is ASSUMED that the addBufferItem function is
    // called with indices which are monotonically increasing, and are not duplicated or out of order
    // or anything weird; assume called from the buffer setting loop in the PixelMap._write method.
    //
    struct CellInfo {

        class BlockInfo {
            var foreground: Bool
            var blend: Float
            var index: Int
            var count: Int
            var lindex: Int
            init(index: Int, count: Int, lindex: Int, foreground: Bool = true, blend: Float = 0.0) {
                self.index = index
                self.count = count
                self.lindex = lindex
                self.foreground = foreground
                self.blend = blend
            }
        }

        let x: Int
        let y: Int
        var blocks: [BlockInfo] = []

        init(x: Int, y: Int) {
            print("CELL-INFO-INIT: \(x) \(y)")
            self.x = x
            self.y = y
        }

        mutating func addBufferItem(_ index: Int, foreground: Bool, blend: Float = 0.0) {
            if let last = blocks.last, last.foreground == foreground, last.blend == blend,
                          index == last.lindex + Memory.bufferBlockSize {
                last.count += 1
                last.lindex = index
            } else {
                blocks.append(BlockInfo(index: index, count: 1, lindex: index, foreground: foreground, blend: blend))
            }
        }

        public func write(_ buffer: inout [UInt8], foreground: PixelValue, background: PixelValue, limit: Bool = false) {
            buffer.withUnsafeMutableBytes { raw in
                for block in self.blocks {
                    let base: UnsafeMutableRawPointer = raw.baseAddress!.advanced(by: block.index)
                    var color: PixelValue = PixelValue.black
                    if (block.foreground) {
                        if (block.blend != 0.0) {
                            color = PixelValue(CellInfo.blend(foreground.red,   background.red,   amount: block.blend),
                                               CellInfo.blend(foreground.green, background.green, amount: block.blend),
                                               CellInfo.blend(foreground.blue,  background.blue,  amount: block.blend),
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

        public func writeNew(_ buffer: inout [UInt8], foreground: PixelValue, background: PixelValue, limit: Bool = false, cellSizeTmp: Int, cellsXTmp: Int, cellInfoBaseTmp: CellInfo, displayWidthTmp: Int) {
            //if (x != 1) || (y != 1) { return }
            // let offset: Int = ((cellSizeTmp * self.x) + (cellSizeTmp * cellSizeTmp * cellsXTmp * self.y)) * ScreenInfo.depth
            // let offset: Int = ((cellSizeTmp * self.x) + (cellSizeTmp * cellSizeTmp * cellsXTmp * self.y)) * ScreenInfo.depth
            let offset: Int = ((cellSizeTmp * self.x) + (cellSizeTmp * displayWidthTmp * self.y)) * ScreenInfo.depth
            print("xyzzy.writeNew: xy: \(self.x) \(self.y) offset: \(offset) dw: \(displayWidthTmp)")
            buffer.withUnsafeMutableBytes { raw in
                for block in cellInfoBaseTmp.blocks {
                    let base: UnsafeMutableRawPointer = raw.baseAddress!.advanced(by: block.index + offset)
                    var color: PixelValue = PixelValue.black
                    if (block.foreground) {
                        if (block.blend != 0.0) {
                            color = PixelValue(CellInfo.blend(foreground.red,   background.red,   amount: block.blend),
                                               CellInfo.blend(foreground.green, background.green, amount: block.blend),
                                               CellInfo.blend(foreground.blue,  background.blue,  amount: block.blend),
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
    }

    struct Defaults {
        public static let displayWidth: Int = ScreenInfo.initialWidth
        public static let displayHeight: Int = ScreenInfo.initialHeight
        public static let displayScale: CGFloat = ScreenInfo.initialScale
        public static let displayScaling: Bool = true
        public static let displayTransparency: UInt8 = 255
        public static let cellSize: Int = 67
        public static let cellSizeNeat: Bool = true
        public static let cellPadding: Int = 2
        public static let cellBleeds: Bool = false
        public static let cellShape: PixelShape = PixelShape.rounded // PixelShape.rounded
        public static let cellColorMode: ColorMode = ColorMode.color
        public static let cellBackground: PixelValue = PixelValue.dark
        public static let cellAntialiasFade: Float = 0.6
        public static let cellRoundedRectangleRadius: Float = 0.25
        public static let cellLimitUpdate: Bool = true
        public static let cellInfoCaching: Bool = true
    }

    struct Core {
        public var displayWidth: Int = Defaults.displayWidth
        public var displayHeight: Int = Defaults.displayWidth
        public var displayScale: CGFloat = Defaults.displayScale
        public var displayScaling: Bool = Defaults.displayScaling
        public var displayTransparency: UInt8 = Defaults.displayTransparency
        public var cellSize: Int = Defaults.cellSize
        public var cellSizeNeat: Bool = Defaults.cellSizeNeat
        public var cellPadding: Int = Defaults.cellPadding
        public var cellBleeds: Bool = Defaults.cellBleeds
        public var cellShape: PixelShape = Defaults.cellShape
        public var cellColorMode: ColorMode = Defaults.cellColorMode
        public var cellBackground: PixelValue = Defaults.cellBackground
        public var cellAntialiasFade: Float = Defaults.cellAntialiasFade
        public var cellRoundedRectangleRadius: Float = Defaults.cellRoundedRectangleRadius
        public var cellLimitUpdate: Bool = Defaults.cellLimitUpdate
        public var cellInfoCaching: Bool = Defaults.cellInfoCaching
    }

    @Published var image: CGImage? = nil

    private var _displayWidth: Int = ScreenInfo.initialWidth
    private var _displayHeight: Int = ScreenInfo.initialHeight
    private var _displayScale: CGFloat = ScreenInfo.initialScale
    private var _displayScaling: Bool = Defaults.displayScaling
    private var _cellSize: Int = Defaults.cellSize
    private var _cellPadding: Int = Defaults.cellPadding
    private var _cellBleeds: Bool = Defaults.cellBleeds
    private var _cellShape: PixelShape = Defaults.cellShape
    private var _cellColorMode: ColorMode = Defaults.cellColorMode
    private var _cellBackground: PixelValue = Defaults.cellBackground
    private var _cellAntialiasFade: Float = Defaults.cellAntialiasFade
    private var _cellRoundedRectangleRadius: Float = Defaults.cellRoundedRectangleRadius
    private var _cellLimitUpdate: Bool = Defaults.cellLimitUpdate
    private var _bufferSize: Int = 0
    private var _buffer: [UInt8] = []
    private var _cells: [CellInfo] = []
    private let _colorSpace = CGColorSpaceCreateDeviceRGB()
    private let _bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
    private static var _cellInfoBaseTmp: CellInfo? = nil

    func configure(screen: ScreenInfo,
                   displayWidth: Int = Defaults.displayWidth,
                   displayHeight: Int = Defaults.displayHeight,
                   cellSize: Int = Defaults.cellSize,
                   cellSizeNeat: Bool = Defaults.cellSizeNeat,
                   cellPadding: Int = Defaults.cellPadding,
                   cellBleeds: Bool = Defaults.cellBleeds,
                   cellShape: PixelShape = Defaults.cellShape,
                   cellColorMode: ColorMode = Defaults.cellColorMode,
                   cellBackground: PixelValue = Defaults.cellBackground,
                   displayScaling: Bool = Defaults.displayScaling,
                   cellInfoCaching: Bool = Defaults.cellInfoCaching)
    {
        self._displayScale = screen.scale
        self._displayScaling = [PixelShape.square, PixelShape.inset].contains(cellShape) ? false : displayScaling
        self._displayWidth = scaled(displayWidth)
        self._displayHeight = scaled(displayHeight)

        self._cellSize = scaled(cellSize)
        self._cellPadding = scaled(cellPadding)
        self._cellBleeds = cellBleeds
        self._cellShape = cellShape
        self._cellColorMode = cellColorMode
        self._cellBackground = cellBackground
        self._bufferSize = self._displayWidth * self._displayHeight * ScreenInfo.depth
        self._buffer = [UInt8](repeating: 0, count: self._bufferSize)

        let neatCells = PixelMap._preferredCellSizes(unscaled(self._displayWidth), unscaled(self._displayHeight))
        print("NEAT-CELL-SIZES-US:")
        for neatCell in neatCells {
            print("NEAT-CELL-US: \(neatCell.cellSize) | \(neatCell.displayWidth) \(neatCell.displayHeight) | \(unscaled(self._displayWidth) - neatCell.displayWidth) \(unscaled(self._displayHeight) - neatCell.displayHeight)")
        }
        if (cellSizeNeat) {
            if let neatCell = PixelMap._closestPreferredCellSize(in: neatCells, to: unscaled(self._cellSize)) {
                print("ORIG-CELL-SIZE:            \(scaled(cellSize))")
                print("ORIG-CELL-SIZE-US:         \(cellSize)")
                print("NEAT-CELL-SIZE:            \(scaled(neatCell.cellSize))")
                print("NEAT-CELL-SIZE-US:         \(neatCell.cellSize)")
                print("NEAT-DISPLAY-SIZE:         \(scaled(neatCell.displayWidth)) x \(scaled(neatCell.displayHeight))")
                print("NEAT-DISPLAY-SIZE-US:      \(neatCell.displayWidth) x \(neatCell.displayHeight)")
                print("NEAT-DISPLAY-MARGIN-XY:    \(self._displayWidth - scaled(neatCell.displayWidth)) , \(self._displayHeight - scaled(neatCell.displayHeight))")
                print("NEAT-DISPLAY-MARGIN-XY-US: \(unscaled(self._displayWidth) - neatCell.displayWidth) , \(unscaled(self._displayHeight) - neatCell.displayHeight)")
                self._cellSize = scaled(neatCell.cellSize)
                self._displayWidth = scaled(neatCell.displayWidth)
                self._displayHeight = scaled(neatCell.displayHeight)
            }
            else {
                print("xyzzy.no-neat-cell")
            }
        }

        print("SCREEN-SCALE-INITIAL:   \(ScreenInfo.initialScale)")
        print("SCREEN-SCALE:           \(screen.scale)")
        print("SCREEN-SIZE:            \(scaled(screen.width)) x \(scaled(screen.height))")
        print("SCREEN-SIZE-US:         \(screen.width) x \(screen.height)")
        print("DISPLAY-SCALING:        \(self._displayScaling)")
        print("DISPLAY-SIZE:           \(self._displayWidth) x \(self._displayHeight)")
        print("DISPLAY-SIZE-US:        \(unscaled(self._displayWidth)) x \(unscaled(self._displayHeight))")
        print("CELL-MAP-SIZE:          \(self.width) x \(self.height)")
        print("CELL-SIZE:              \(self.cellSize)")
        print("CELL-SIZE-US:           \(unscaled(self._cellSize))")
        print("CELL-PADDING:           \(self.cellPadding)")
        print("CELL-PADDING-US:        \(unscaled(self.cellPadding))")
        print("BUFFER-SIZE:            \(self._bufferSize)")

        if (cellInfoCaching) {
            self._initializeCells()
        }

        self.fill(with: PixelValue.dark, update: true)
    }

    private func _initializeCells() {
        PixelMap._cellInfoBaseTmp = nil
        self._cells = []
        for y in 0..<self.height {
            for x in 0..<self.width {
                if let cellInfo = PixelMap._write(&self._buffer,
                                                  self._displayWidth,
                                                  self._displayHeight,
                                                  x: x,
                                                  y: y,
                                                  cellSize: self.cellSize,
                                                  red: 0,
                                                  green: 0,
                                                  blue: 0,
                                                  cellShape: self.cellShape,
                                                  cellPadding: self.cellPadding,
                                                  background: self.background,
                                                  forCellInfo: true) {
                    self._cells.append(cellInfo)
                    if ((x == 0) && (y == 0)) {
                        PixelMap._cellInfoBaseTmp = cellInfo
                        print("_cellInfoBaseTmp: \(PixelMap._cellInfoBaseTmp!.x) \(PixelMap._cellInfoBaseTmp!.y)")
                    }
                }
            }
        }
    }

    private static func _preferredCellSizes(_ displayWidth: Int,
                                            _ displayHeight: Int,
                                            displaySizeVariationMax: Int = 10) -> [(cellSize: Int,
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

    private static func _closestPreferredCellSize(in list: [(cellSize: Int, displayWidth: Int, displayHeight: Int)],
                                                  to target: Int) -> (cellSize: Int, displayWidth: Int, displayHeight: Int)? {
        return list.min(by: {
            let a = abs($0.cellSize - target)
            let b = abs($1.cellSize - target)
            return (a, $0.cellSize) < (b, $1.cellSize)
        })
    }

    public var displayScale: CGFloat {
        self._displayScaling ? self._displayScale : 1
    }

    private func scaled(_ value: Int) -> Int {
        self._displayScaling ? Int(round(CGFloat(value) * self.displayScale)) : value
    }

    private func unscaled(_ value: Int) -> Int {
        self._displayScaling ? Int(round(CGFloat(value) / self.displayScale)) : value
    }

    // Returns the logical width of this PixelMap, i.e. the number of
    // cell-size-sized cells that can fit across the width of the display.
    //
    public var width: Int {
        self._cellBleeds ? ((self._displayWidth + self._cellSize - 1) / self._cellSize)
                         : (self._displayWidth / self._cellSize)
    }

    // Returns the logical height of this PixelMap, i.e. the number of
    // cell-size-sized cells that can fit down the height of the display.
    //
    public var height: Int {
        self._cellBleeds ? ((self._displayHeight + self._cellSize - 1) / self._cellSize)
                         : (self._displayHeight / self._cellSize)
    }

    public var cellSize: Int {
        self._cellSize
    }

    public var cellPadding: Int {
        self._cellPadding
    }

    public var cellShape: PixelShape {
        self._cellShape
    }

    public var cellColorMode: ColorMode {
        self._cellColorMode
    }

    public var background: PixelValue {
        self._cellBackground
    }

    // Returns the cell coordinate for the given display input coordinates.
    //
    public func locate(_ screenPoint: CGPoint) -> CGPoint? {
        print("LOCATE: \(screenPoint)")
        var screenX: CGFloat = screenPoint.x
        var screenY: CGFloat = screenPoint.y
        print("LOCATE-XY: \(screenX) , \(screenY)")
        if ((screenX < 0.0) || (screenY < 0.0) ||
            (screenX > CGFloat(unscaled(self._displayWidth))) ||
            (screenY > CGFloat(unscaled(self._displayHeight)))) {
            print("LOCATE-OUT-OF-BOUNDS: \(screenPoint) -> \(screenPoint) -> \(self._displayWidth) x \(self._displayHeight) -> NIL")
            return nil
        }
        var screeniX: Int = Int(screenX)
        var screeniY: Int = Int(screenY)
        print("LOCATE-IXY: \(screeniX) , \(screeniY)")
        print("LOCATE-OK: \(screenPoint) -> \(CGPoint(x: Int(screeniX / unscaled(self._cellSize)), y: Int(screeniY / unscaled(self._cellSize))))")
        return CGPoint(x: Int(screeniX / unscaled(self._cellSize)), y: Int(screeniY / unscaled(self._cellSize)))
    }

    public func cell(_ x: Int, _ y: Int) -> CellInfo? {
        for cellInfo in self._cells {
            if ((cellInfo.x == x) && (cellInfo.y == y)) {
                return cellInfo
            }
        }
        return nil
    }

    public func onDrag(_ location: CGPoint) {
        if let clocation = self.locate(location)   {
            let color = PixelValue(0, 0, 255)
            print("DRAG: \(location) -> \(clocation)")
            self.write(x: Int(clocation.x), y: Int(clocation.y), red: color.red, green: color.green, blue: color.blue)
            self.update()
        }
    }

    public func onDragEnd(_ location: CGPoint) {
        let color = PixelValue.random()
        self.write(x: Int(location.x), y: Int(location.y), red: color.red, green: color.green, blue: color.blue)
        self.update()
    }

    public func onTap(_ location: CGPoint) {
        print("ON-TAP: \(location)")
        if let clocation = self.locate(location) {
            print("TAP: \(location) -> \(clocation)")
            self.randomize()
            self.update()
        }
    }

    func fill(with pixel: PixelValue = PixelValue.dark, update: Bool = false) {
        for y in 0..<self._displayHeight {
            for x in 0..<self._displayWidth {
                let i = (y * self._displayWidth + x) * ScreenInfo.depth
                self._buffer[i + 0] = pixel.red
                self._buffer[i + 1] = pixel.green
                self._buffer[i + 2] = pixel.blue
                self._buffer[i + 3] = pixel.alpha
            }
        }
        if (update) {
            self.update()
        }
    }

    func update() {
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
                space: self._colorSpace,
                bitmapInfo: self._bitmapInfo
            ) {
                self.image = context.makeImage()
            }
        }
    }

    func randomize() {
        PixelMap._randomize(&self._buffer,
                            self._displayWidth,
                            self._displayHeight,
                            width: self.width,
                            height: self.height,
                            cellSize: self.cellSize,
                            cellColorMode: self.cellColorMode,
                            cellShape: self.cellShape,
                            cellPadding: self.cellPadding,
                            background: self.background,
                            cells: self._cells)
    }

    static func _randomize(_ buffer: inout [UInt8],
                           _ displayWidth: Int,
                           _ displayHeight: Int,
                           width: Int, height: Int,
                           cellSize: Int,
                           cellColorMode: ColorMode,
                           cellShape: PixelShape,
                           cellPadding: Int,
                           background: PixelValue = PixelValue.dark,
                           cells: [CellInfo])
    {
        let start = Date()

        if (!cells.isEmpty) {
            let cellsXTmp: Int = (displayWidth / cellSize) // self.width
            for cell in cells {
                // cell.write(&buffer, foreground: PixelValue.random(), background: background, limit: Defaults.cellLimitUpdate) // xyz
                cell.writeNew(&buffer, foreground: PixelValue.random(), background: background, limit: Defaults.cellLimitUpdate, cellSizeTmp: cellSize, cellsXTmp: cellsXTmp, cellInfoBaseTmp: PixelMap._cellInfoBaseTmp!, displayWidthTmp: displayWidth)
            }
            let end = Date()
            let elapsed = end.timeIntervalSince(start)
            print(String(format: "RANDOMIZE-OPTIMIZED-TIME: %.5f seconds", elapsed))
            return
        }

        for y in 0..<height {
            for x in 0..<width {
                if (cellColorMode == ColorMode.monochrome) {
                    let value: UInt8 = UInt8.random(in: 0...1) * 255
                    PixelMap._write(&buffer,
                                    displayWidth,
                                    displayHeight,
                                    x: x,
                                    y: y,
                                    cellSize: cellSize,
                                    red: value, green: value, blue: value,
                                    cellShape: cellShape,
                                    cellPadding: cellPadding,
                                    background: background)
                }
                else if (cellColorMode == ColorMode.grayscale) {
                    let value = UInt8.random(in: 0...255)
                    PixelMap._write(&buffer,
                                    displayWidth,
                                    displayHeight,
                                    x: x,
                                    y: y,
                                    cellSize: cellSize,
                                    red: value,
                                    green: value,
                                    blue: value,
                                    cellShape: cellShape,
                                    cellPadding: cellPadding,
                                    background: background)
                }
                else {
                    var rgb = UInt32.random(in: 0...0xFFFFFF)
                    let red = UInt8((rgb >> 16) & 0xFF)
                    let green = UInt8((rgb >> 8) & 0xFF)
                    let blue = UInt8(rgb & 0xFF)
                    PixelMap._write(&buffer,
                                    displayWidth,
                                    displayHeight,
                                    x: x,
                                    y: y,
                                    cellSize: cellSize,
                                    red: red,
                                    green: green,
                                    blue: blue,
                                    cellShape: cellShape,
                                    cellPadding: cellPadding,
                                    background: background)
                }
            }
        }
        let end = Date()
        let elapsed = end.timeIntervalSince(start)
        print(String(format: "RANDOMIZE-TIME: %.5f seconds", elapsed))
    }

    func write(x: Int, y: Int, red: UInt8, green: UInt8, blue: UInt8, transparency: UInt8 = PixelMap.Defaults.displayTransparency) {
        if (!self._cells.isEmpty) {
            if let cell = self.cell(x, y) {
                // cell.write(&self._buffer, foreground: PixelValue(red, green, blue), background: self.background, limit: Defaults.cellLimitUpdate) // xyz
                print("WRITE-NEW: xy: \(cell.x) \(cell.y) cells-x: \(self.width) cell-size: \(self._cellSize)")
                cell.writeNew(&self._buffer, foreground: PixelValue(red, green, blue), background: self.background, limit: Defaults.cellLimitUpdate, cellSizeTmp: self._cellSize, cellsXTmp: self.width, cellInfoBaseTmp: PixelMap._cellInfoBaseTmp!, displayWidthTmp: self._displayWidth)
            }
            return
        }
        PixelMap._write(&self._buffer,
                        self._displayWidth,
                        self._displayHeight,
                        x: x,
                        y: y,
                        cellSize: self.cellSize,
                        red: red,
                        green: green,
                        blue: blue,
                        transparency: transparency,
                        cellShape: self.cellShape,
                        cellPadding: self.cellPadding,
                        background: self.background)
    }

    static func _write(_ buffer: inout [UInt8],
                       _ displayWidth: Int,
                       _ displayHeight: Int,
                       x: Int,
                       y: Int,
                       cellSize: Int,
                       red: UInt8,
                       green: UInt8,
                       blue: UInt8,
                       transparency: UInt8 = PixelMap.Defaults.displayTransparency,
                       cellShape: PixelShape = .rounded,
                       cellPadding: Int = 0,
                       background: PixelValue = PixelValue.dark,
                       forCellInfo: Bool = false) -> CellInfo?
    {
        if ((x < 0) || (y < 0)) {
            return nil
        }

        var cellInfo: CellInfo? = forCellInfo ? CellInfo(x: x, y: y) : nil

        var cellPaddingThickness = 0
        if ((cellPadding > 0) && (cellSize >= 6) && (cellShape != .square)) {
            cellPaddingThickness = cellPadding
        }

        let startX = x * cellSize
        let startY = y * cellSize
        // let startX = (x * cellSize)
        // let startY = (y * cellSize)
        let endX = (startX + cellSize)
        let endY = (startY + cellSize)
        let adjustedScale = cellSize - 2 * cellPaddingThickness
        let centerX = Float(startX + cellSize / 2)
        let centerY = Float(startY + cellSize / 2)
        let circleRadius = Float(adjustedScale) / 2.0
        let radiusSquared = circleRadius * circleRadius
        let fadeRange: Float = 0.6  // smaller -> smoother

        func blend(a: UInt8, b: UInt8, t: Float) -> UInt8 {
            return UInt8(Float(a) * t + Float(b) * (1 - t))
        }

        for dy in 0..<cellSize {
            for dx in 0..<cellSize {
                let ix = startX + dx
                let iy = startY + dy
                if ix >= displayWidth || iy >= displayHeight { continue }

                let fx = Float(ix) + 0.5
                let fy = Float(iy) + 0.5

                var coverage: Float = 0.0

                switch cellShape {
                case .square, .inset:
                    if dx >= cellPaddingThickness && dx < cellSize - cellPaddingThickness &&
                       dy >= cellPaddingThickness && dy < cellSize - cellPaddingThickness {
                        coverage = 1.0
                    }

                case .circle:
                    let dxSq = (fx - centerX) * (fx - centerX)
                    let dySq = (fy - centerY) * (fy - centerY)
                    let dist = sqrt(dxSq + dySq)
                    let d = circleRadius - dist
                    coverage = max(0.0, min(1.0, d / fadeRange))

                case .rounded:
                    let cornerRadius = Float(adjustedScale) * 0.25
                    let cr2 = cornerRadius * cornerRadius
                    let minX = Float(startX + cellPaddingThickness)
                    let minY = Float(startY + cellPaddingThickness)
                    let maxX = Float(endX - cellPaddingThickness)
                    let maxY = Float(endY - cellPaddingThickness)

                    if fx >= minX + cornerRadius && fx <= maxX - cornerRadius {
                        if fy >= minY && fy <= maxY {
                            coverage = 1.0
                        }
                    } else if fy >= minY + cornerRadius && fy <= maxY - cornerRadius {
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

                let i = (iy * displayWidth + ix) * 4
                if i >= 0 && i + 3 < buffer.count {
                    let alpha = UInt8(Float(transparency) * coverage)
                    if coverage > 0 {
                        if (cellInfo != nil) {
                            cellInfo!.addBufferItem(i, foreground: true, blend: coverage)
                        }
                        else {
                            buffer[i]     = blend(a: red, b: background.red, t: coverage)
                            buffer[i + 1] = blend(a: green, b: background.green, t: coverage)
                            buffer[i + 2] = blend(a: blue, b: background.blue, t: coverage)
                            buffer[i + 3] = transparency
                        }

                    } else {
                        if cellInfo != nil {
                            cellInfo!.addBufferItem(i, foreground: false)
                        }
                        else {
                            buffer[i]     = background.red
                            buffer[i + 1] = background.green
                            buffer[i + 2] = background.blue
                            buffer[i + 3] = transparency
                        }
                    }
                }
            }
        }
        return cellInfo
    }
}
