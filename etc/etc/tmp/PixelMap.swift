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

        private static func blend(_ a: UInt8, _ b: UInt8, amount: Float) -> UInt8 {
            return UInt8(Float(a) * amount + Float(b) * (1 - amount))
        }
    }

    struct Defaults {
        public static let displayWidth: Int = ScreenInfo.initialWidth
        public static let displayHeight: Int = ScreenInfo.initialHeight
        public static let displayScale: CGFloat = ScreenInfo.initialScale
        public static let displayScaling: Bool = true
        public static let displayTransparency: UInt32 = 255
        public static let marginX: Int = 20
        public static let marginY: Int = 20
        public static let cellSize: Int = 30
        public static let cellPadding: Int = 2
        public static let cellShape: PixelShape = PixelShape.rounded
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
        public var displayTransparency: UInt32 = Defaults.displayTransparency
        public var marginX: Int = Defaults.marginX
        public var marginY: Int = Defaults.marginY
        public var cellSize: Int = Defaults.cellSize
        public var cellPadding: Int = Defaults.cellPadding
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
    private var _marginX: Int = Defaults.marginX
    private var _marginY: Int = Defaults.marginY
    private var _cellSize: Int = Defaults.cellSize
    private var _cellPadding: Int = Defaults.cellPadding
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

    func configure(screen: ScreenInfo,
                   displayWidth: Int = Defaults.displayWidth,
                   displayHeight: Int = Defaults.displayHeight,
                   marginX: Int = Defaults.marginX,
                   marginY: Int = Defaults.marginY,
                   cellSize: Int = Defaults.cellSize,
                   cellPadding: Int = Defaults.cellPadding,
                   cellShape: PixelShape = Defaults.cellShape,
                   cellColorMode: ColorMode = Defaults.cellColorMode,
                   cellBackground: PixelValue = Defaults.cellBackground,
                   displayScaling: Bool = Defaults.displayScaling,
                   cellInfoCaching: Bool = Defaults.cellInfoCaching)
    {
        self._displayScale = screen.scale
        self._displayScaling = displayScaling

        self._marginX = scaled(marginX)
        self._marginY = scaled(marginY)

        self._displayWidth = scaled(displayWidth) // ds ? ScreenInfo.scaledValue(displayWidth, scale: screen.scale) : self._displayWidthUnscaled
        self._displayHeight = scaled(displayHeight) // ds ? ScreenInfo.scaledValue(self._displayHeightUnscaled, scale: screen.scale) : self._displayHeightUnscaled
        // self._displayWidth -= self._marginX * 2
        // self._displayHeight -= self._marginY * 2
        // print("POST-MARGIN-DISPLAY-SIZE: \(self._displayWidth) \(self._displayHeight) | \(self._marginX) \(self._marginY) | \(self._marginXUnscaled) \(self._marginYUnscaled)")

        self._cellSize = scaled(cellSize) // ds ? ScreenInfo.scaledValue(cellSize, scale: screen.scale) : cellSize
        self._cellPadding = scaled(cellPadding) // ds ? ScreenInfo.scaledValue(cellPadding, scale: screen.scale) : cellPadding
        self._cellShape = cellShape
        self._cellColorMode = cellColorMode
        self._cellBackground = cellBackground
        // self._bufferSize = displayScaling ? screen.scaledBufferSize : screen.bufferSize
        self._bufferSize = self._displayWidth * self._displayHeight * ScreenInfo.depth
        self._buffer = [UInt8](repeating: 0, count: self._bufferSize)

        print("SCREEN-SCALE:       \(screen.scale)")
        print("SCREEN-SIZE:        \(screen.scaledWidth) x \(screen.scaledHeight)")
        print("SCREEN-SIZE-US:     \(screen.width) x \(screen.height)")
        print("DISPLAY-SCALING:    \(displayScaling)")
        print("DISPLAY-SIZE:       \(self._displayWidth) x \(self._displayHeight)")
        print("DISPLAY-SIZE-US:    \(unscaled(self._displayWidth)) x \(unscaled(self._displayHeight))")
        print("MARGIN-XY:          \(self._marginX) , \(self._marginY)")
        print("MARGIN-XY-US:       \(unscaled(self._marginX)) , \(unscaled(self._marginY))")
        print("CELL-MAP-SIZE:      \(self.width) x \(self.height)")
        print("CELL-SIZE:          \(self.cellSize)")
        print("CELL-SIZE-US:       \(unscaled(self._cellSize))")
        print("CELL-PADDING:       \(self.cellPadding)")
        print("CELL-PADDING-US:    \(unscaled(self.cellPadding))")
        print("BUFFER-SIZE:        \(self._bufferSize)")

        var preferredCellSizes = PixelMap._computePreferredCellSizes(self._displayWidth, self._displayHeight)

        if (cellInfoCaching) {
            self._initializeCells()
        }

        self.fill(with: PixelValue.dark, update: true)
    }

    private func _initializeCells() {
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
                                                  marginX: self._marginX,
                                                  marginY: self._marginY,
                                                  forCellInfo: true) {
                    self._cells.append(cellInfo)
                }
            }
        }
    }

    private static func _computePreferredCellSizes(_ displayWidth: Int, _ displayHeight: Int, maxExtraPadding: Int = 8) -> [(cellSize: Int, marginX: Int, marginY: Int)] {
        let minDimension = min(displayWidth, displayHeight)
        guard minDimension > 0 else { return [] }
        var results: [(cellSize: Int, marginX: Int, marginY: Int)] = []
        for cellSize in 1...minDimension {
            let cellsX = displayWidth / cellSize
            let cellsY = displayHeight / cellSize
            let usedWidth = cellsX * cellSize
            let usedHeight = cellsY * cellSize
            let leftoverX = displayWidth - usedWidth
            let leftoverY = displayHeight - usedHeight
            if leftoverX <= maxExtraPadding && leftoverY <= maxExtraPadding {
                let marginX = leftoverX / 2
                let marginY = leftoverY / 2
                results.append((cellSize: cellSize, marginX: marginX, marginY: marginY))
            }
        }
        print("PREFERRED-CELL-SIZES: \(results.map { "\($0.cellSize) \($0.marginX) \($0.marginX)" })")
        return results
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
        (self._displayWidth + self._cellSize - 1) / self._cellSize
    }

    // Returns the logical height of this PixelMap, i.e. the number of
    // cell-size-sized cells that can fit down the height of the display.
    //
    public var height: Int {
        (self._displayHeight + self._cellSize - 1) / self._cellSize
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
        var screenX: CGFloat = screenPoint.x - CGFloat(unscaled(self._marginX))
        var screenY: CGFloat = screenPoint.y - CGFloat(unscaled(self._marginY))
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
            let color = PixelValue.black
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
                            marginX: self._marginX,
                            marginY: self._marginY,
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
                           marginX: Int = 0,
                           marginY: Int = 0,
                           cells: [CellInfo])
    {
        let start = Date()

        if (!cells.isEmpty) {
            for cell in cells {
                cell.write(&buffer, foreground: PixelValue.random(), background: background, limit: Defaults.cellLimitUpdate)
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
                                    background: background,
                                    marginX: marginX,
                                    marginY: marginY)
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
                                    background: background,
                                    marginX: marginX,
                                    marginY: marginY)
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
                                    background: background,
                                    marginX: marginX,
                                    marginY: marginY)
                }
            }
        }
        let end = Date()
        let elapsed = end.timeIntervalSince(start)
        print(String(format: "RANDOMIZE-TIME: %.5f seconds", elapsed))
    }

    func write(x: Int, y: Int, red: UInt8, green: UInt8, blue: UInt8, transparency: UInt8 = 255) {
        if (!self._cells.isEmpty) {
            if let cell = self.cell(x, y) {
                cell.write(&self._buffer, foreground: PixelValue(red, green, blue), background: self.background, limit: Defaults.cellLimitUpdate)
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
                        background: self.background,
                        marginX: self._marginX,
                        marginY: self._marginY)
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
                       transparency: UInt8 = 255,
                       cellShape: PixelShape = .rounded,
                       cellPadding: Int = 0,
                       background: PixelValue = PixelValue.dark,
                       marginX: Int = 0,
                       marginY: Int = 0,
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

        let startX = marginX + (x * cellSize)
        let startY = marginY + (y * cellSize)
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
