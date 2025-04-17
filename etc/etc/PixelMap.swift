import CoreGraphics
import Foundation
import SwiftUI

@MainActor
class PixelMap: ObservableObject {

    // This is mainly (was first created) for keeping track of the foreground/background buffer
    // indices for each cell, for the purpose of being able to write the values very fast using
    // block memory copy (see Memory.fastcopy). It is ASSUMED that the addBufferIndexFourground
    // and addBufferIndexBackground function are called with indices which are monotonically
    // increasing, and are not duplicated or anything weird; assumes called from the buffer
    // setting loop in the PixelMap._write method.
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

        public func write(_ buffer: inout [UInt8], foreground: PixelValue, background: PixelValue) {
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

    @Published var image: CGImage? = nil

    private var _displayWidth: Int = 0
    private var _displayHeight: Int = 0
    private var _displayScale: CGFloat = 0.0
    private var _displayScaling: Bool = true
    private var _cellSize: Int = 15 // 120 // 40
    private var _cellSizeUnscaled: Int = 15
    private var _cellPadding: Int = 2
    private var _cellShape: PixelShape = PixelShape.rounded
    private var _cellColorMode: ColorMode = ColorMode.color
    private var _cellBackground: PixelValue = PixelValue.dark
    private var _bufferSize: Int = 0
    private var _buffer: [UInt8] = []
    private var _cells: [CellInfo] = []
    private let _colorSpace = CGColorSpaceCreateDeviceRGB()
    private let _bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue

    func configure(screen: ScreenInfo,
                   cellSize: Int = 15, // 120, // 40,
                   cellPadding: Int = 2,
                   cellShape: PixelShape = PixelShape.rounded,
                   cellColorMode: ColorMode = ColorMode.color,
                   cellBackground: PixelValue = PixelValue.dark,
                   displayScaling: Bool = true,
                   cellInfoCaching: Bool = true)
    {
        self._displayWidth = displayScaling ? screen.scaledWidth : screen.width
        self._displayHeight = displayScaling ? screen.scaledHeight : screen.height
        self._displayScale = screen.scale
        self._displayScaling = displayScaling

        self._cellSize = displayScaling ? ScreenInfo.scaledValue(cellSize, scale: screen.scale) : cellSize
        self._cellSizeUnscaled = cellSize
        self._cellPadding = displayScaling ? ScreenInfo.scaledValue(cellPadding, scale: screen.scale) : cellPadding
        self._cellShape = cellShape
        self._cellColorMode = cellColorMode
        self._cellBackground = cellBackground
        self._bufferSize = displayScaling ? screen.scaledBufferSize : screen.bufferSize
        self._buffer = [UInt8](repeating: 0, count: self._bufferSize)

        print("DISPLAY-SCALING:      \(displayScaling)")
        print("DISPLAY-SIZE:         \(screen.width) x \(screen.height)")
        print("DISPLAY-SCALE:        \(screen.scale)")
        print("DISPLAY-SCALED-WIDTH: \(screen.scaledWidth) x \(screen.scaledHeight)")
        print("CELL-SIZE:            \(self.cellSize)")
        print("CELL-SIZE-UNSCALED:   \(self._cellSizeUnscaled)")
        print("PIXMAP-SIZE:          \(self.width) x \(self.height)")
        print("BUFFER-SIZE:          \(self._bufferSize)")

        if (cellInfoCaching) {
            self._initializeCells()
        }

        self.fill(with: PixelValue.dark, update: true)
    }

    private func _initializeCells() {
        self._cells = []
        for y in 0..<self.height {
            for x in 0..<self.width {
                if let cellInfo = PixelMap._write(&self._buffer, self._displayWidth, self._displayHeight,
                                                  x: x, y: y,
                                                  cellSize: self.cellSize,
                                                  red: 0, green: 0, blue: 0,
                                                  cellShape: self.cellShape,
                                                  background: self.background,
                                                  cellPadding: self.cellPadding,
                                                  forCellInfo: true) {
                    self._cells.append(cellInfo)
                }
            }
        }
    }

    public var displayScale: CGFloat {
        self._displayScaling ? self._displayScale : 1
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

    public func locate(_ screenPoint: CGPoint) -> CGPoint {
        let screenX = max(Int(screenPoint.x), 0)
        let screenY = max(Int(screenPoint.y), 0)
        return CGPoint(x: Int(screenX / self._cellSizeUnscaled), y: Int(screenY / self._cellSizeUnscaled))
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
        let clocation = self.locate(location)  
        let color = PixelValue.black
        self.write(x: Int(clocation.x), y: Int(clocation.y), red: color.red, green: color.green, blue: color.blue)
        self.update()
    }

    public func onDragEnd(_ location: CGPoint) {
        let color = PixelValue.random()
        self.write(x: Int(location.x), y: Int(location.y), red: color.red, green: color.green, blue: color.blue)
        self.update()
    }

    public func onTap(_ location: CGPoint) {
        self.randomize()
        self.update()
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
        PixelMap._randomize(&self._buffer, self._displayWidth, self._displayHeight,
                            width: self.width, height: self.height,
                            cellSize: self.cellSize, cellColorMode: self.cellColorMode,
                            cellShape: self.cellShape, cellPadding: self.cellPadding,
                            background: self.background,
                            cells: self._cells)
    }

    static func _randomize(_ buffer: inout [UInt8], _ displayWidth: Int, _ displayHeight: Int,
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
            for cell in cells {
                cell.write(&buffer, foreground: PixelValue.random(), background: background) // xyzzy/todo/optional-bg // new
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
                    PixelMap._write(&buffer, displayWidth, displayHeight,
                                    x: x, y: y, cellSize: cellSize,
                                    red: value, green: value, blue: value,
                                    cellShape: cellShape, background: background, cellPadding: cellPadding)
                }
                else if (cellColorMode == ColorMode.grayscale) {
                    let value = UInt8.random(in: 0...255)
                    PixelMap._write(&buffer, displayWidth, displayHeight,
                                    x: x, y: y, cellSize: cellSize,
                                    red: value, green: value, blue: value,
                                    cellShape: cellShape, background: background, cellPadding: cellPadding)
                }
                else {
                    var rgb = UInt32.random(in: 0...0xFFFFFF)
                    let red = UInt8((rgb >> 16) & 0xFF)
                    let green = UInt8((rgb >> 8) & 0xFF)
                    let blue = UInt8(rgb & 0xFF)
                    PixelMap._write(&buffer, displayWidth, displayHeight,
                                    x: x, y: y, cellSize: cellSize,
                                    red: red, green: green, blue: blue,
                                    cellShape: cellShape, background: background, cellPadding: cellPadding)
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
                cell.write(&self._buffer, foreground: PixelValue(red, green, blue), background: self.background)
            }
            return
        }
        PixelMap._write(&self._buffer, self._displayWidth, self._displayHeight,
                        x: x, y: y, cellSize: self.cellSize,
                        red: red, green: green, blue: blue, transparency: transparency,
                        cellShape: self.cellShape, background: self.background,
                        cellPadding: self.cellPadding)
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
                       background: PixelValue = PixelValue.dark,
                       cellPadding: Int = 0,
                       forCellInfo: Bool = false) -> CellInfo?
    {
        if x < 0 || y < 0 {
            return nil
        }

        var cellInfo: CellInfo? = forCellInfo ? CellInfo(x: x, y: y) : nil
        // var cellInfo: CellInfo? = CellInfo(x: x, y: y)

        var cellPaddingThickness = 0
        if cellPadding > 0 && cellSize >= 6 && cellShape != .square {
            cellPaddingThickness = cellPadding
        }

        let startX = x * cellSize
        let startY = y * cellSize
        let endX = startX + cellSize
        let endY = startY + cellSize
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
                            // cellInfo!.addBufferItem(i, background: false, blend: coverage)
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

    static func _writeNoAntialiasing(_ buffer: inout [UInt8],
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
                                     background: PixelValue = PixelValue.dark,
                                     cellPadding: Int = 0,
                                     forCellInfo: Bool = false) -> CellInfo?
    {
        if ((x < 0) || (y < 0)) {
            return nil
        }

        let cellPaddingThickness: Int = ((cellPadding > 0) && (cellSize >= 6) && (cellShape != PixelShape.square)) ? cellPadding : 0
        let startX = x * cellSize
        let startY = y * cellSize
        let endX = startX + cellSize
        let endY = startY + cellSize
        let adjustedScale = cellSize - 2 * cellPaddingThickness
        let centerX = Float(startX + cellSize / 2)
        let centerY = Float(startY + cellSize / 2)
        let circleRadius = Float(adjustedScale) / 2.0
        let radiusSquared = circleRadius * circleRadius
        var cellInfo: CellInfo? = forCellInfo ? CellInfo(x: x, y: y) : nil

        for dy in 0..<cellSize {
            for dx in 0..<cellSize {
                let ix = startX + dx
                let iy = startY + dy

                if ix >= displayWidth || iy >= displayHeight { continue }

                let fx = Float(ix) + 0.5
                let fy = Float(iy) + 0.5

                var shouldWrite = false

                switch cellShape {
                case .square, .inset:
                    shouldWrite = (dx >= cellPaddingThickness && dx < cellSize - cellPaddingThickness &&
                                   dy >= cellPaddingThickness && dy < cellSize - cellPaddingThickness)

                case .circle:
                    let dxSq = (fx - centerX) * (fx - centerX)
                    let dySq = (fy - centerY) * (fy - centerY)
                    shouldWrite = dxSq + dySq <= radiusSquared

                case .rounded:
                    let cornerRadius: Float = Float(adjustedScale) * 0.25
                    let cr2 = cornerRadius * cornerRadius

                    let minX = Float(startX + cellPaddingThickness)
                    let minY = Float(startY + cellPaddingThickness)
                    let maxX = Float(endX - cellPaddingThickness)
                    let maxY = Float(endY - cellPaddingThickness)

                    if fx >= minX + cornerRadius && fx <= maxX - cornerRadius {
                        shouldWrite = fy >= minY && fy <= maxY
                    } else if fy >= minY + cornerRadius && fy <= maxY - cornerRadius {
                        shouldWrite = fx >= minX && fx <= maxX
                    } else {
                        let cx = fx < minX + cornerRadius ? minX + cornerRadius :
                                 fx > maxX - cornerRadius ? maxX - cornerRadius : fx
                        let cy = fy < minY + cornerRadius ? minY + cornerRadius :
                                 fy > maxY - cornerRadius ? maxY - cornerRadius : fy
                        let dx = fx - cx
                        let dy = fy - cy
                        shouldWrite = dx * dx + dy * dy <= cr2
                    }
                }

                let i = (iy * displayWidth + ix) * ScreenInfo.depth

                if ((i >= 0) && ((i + 3) < buffer.count)) {
                    if shouldWrite {
                        if (cellInfo != nil) {
                            cellInfo!.addBufferItem(i, foreground: true)
                        }
                        buffer[i] = red
                        buffer[i + 1] = green
                        buffer[i + 2] = blue
                        buffer[i + 3] = transparency
                    } else {
                        if (cellInfo != nil) {
                            cellInfo!.addBufferItem(i, foreground: false)
                        }
                        buffer[i] = background.red
                        buffer[i + 1] = background.green
                        buffer[i + 2] = background.blue
                        buffer[i + 3] = transparency
                    }
                }
            }
        }
        return cellInfo
    }
}
