import CoreGraphics
import Foundation
import SwiftUI

@MainActor
class PixelMap: ObservableObject {

    struct Debug {
        var index: Int
        var set: Bool
    }

    class DebugCellInfo {
        var indicesSet: [Int] = []
        var indicesUnset: [Int] = []
        var indicesSetByBlocks: [[Int]] = []
        var indicesUnsetByBlocks: [[Int]] = []
    }
    static var _cellsInfo: [DebugCellInfo] = []

    static var _randomizeCalledOnce: Bool = false

    static func _consecutiveBlocks(_ input: [Int], step: Int = 4) -> [[Int]] {
        let sorted = input.sorted()
        var result: [[Int]] = []
        var currentBlock: [Int] = []
        for num in sorted {
            if currentBlock.isEmpty || num - currentBlock.last! == step {
                currentBlock.append(num)
            } else {
                result.append(currentBlock)
                currentBlock = [num]
            }
        }
        if !currentBlock.isEmpty {
            result.append(currentBlock)
        }
        return result
    }

    @Published var image: CGImage? = nil

    private var _displayWidth: Int = 0
    private var _displayHeight: Int = 0
    private var _displayChannelSize: Int = 0
    private var _displayScale: CGFloat = 0.0
    private var _displayScalingEnabled: Bool = true
    private var _cellSize: Int = 120 // 40
    private var _cellPadding: Int = 1
    private var _cellShape: PixelShape = PixelShape.rounded
    private var _cellColorMode: ColorMode = ColorMode.color
    private var _cellBackground: PixelValue = PixelValue.dark
    private var _bufferSize: Int = 0
    private var _buffer: [UInt8] = []
    private let _colorSpace = CGColorSpaceCreateDeviceRGB()
    private let _bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue

    func configure(screen: ScreenInfo,
                   cellSize: Int = 120, // 40,
                   cellPadding: Int = 1,
                   cellShape: PixelShape = PixelShape.rounded,
                   cellColorMode: ColorMode = ColorMode.color,
                   cellBackground: PixelValue = PixelValue.white,
                   displayScaling: Bool = true)
    {
        self._displayWidth = displayScaling ? screen.scaledWidth : screen.width
        self._displayHeight = displayScaling ? screen.scaledHeight : screen.height
        self._displayChannelSize = screen.channelSize
        self._displayScale = screen.scale
        self._displayScalingEnabled = displayScaling

        self._cellSize = displayScaling ? ScreenInfo.scaledValue(cellSize, scale: screen.scale) : cellSize
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
        print("PIXMAP-SIZE:          \(self.width) x \(self.height)")
        print("BUFFER-SIZE:          \(self._bufferSize)")

        self.fill(with: PixelValue.light)
        self.update()
    }

    public var displayScale: CGFloat {
        self._displayScalingEnabled ? self._displayScale : 1
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

    func fill(with pixel: PixelValue = PixelValue.dark) {
        // print("FILl: \(self._displayWidth)x\(self._displayHeight)")
        for y in 0..<self._displayHeight {
            for x in 0..<self._displayWidth {
                let i = (y * self._displayWidth + x) * 4
                self._buffer[i + 0] = pixel.red
                self._buffer[i + 1] = pixel.green
                self._buffer[i + 2] = pixel.blue
                self._buffer[i + 3] = pixel.alpha
            }
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
                bytesPerRow: self._displayWidth * self._displayChannelSize,
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
                            background: self.background)
    }

    static func _randomize(_ buffer: inout [UInt8], _ displayWidth: Int, _ displayHeight: Int,
                           width: Int, height: Int,
                           cellSize: Int,
                           cellColorMode: ColorMode,
                           cellShape: PixelShape,
                           cellPadding: Int,
                           background: PixelValue = PixelValue.dark)
    {
        let start = Date()

        if (PixelMap._randomizeCalledOnce) {
            for cellInfo in PixelMap._cellsInfo {
                var rgb = UInt32.random(in: 0...0xFFFFFF)
                let red = UInt8((rgb >> 16) & 0xFF)
                let green = UInt8((rgb >> 8) & 0xFF)
                let blue = UInt8(rgb & 0xFF)
                let transparency = UInt8(255)
                var fg: PixelValue = PixelValue(red, green, blue, alpha: transparency)
                for indicesSet in cellInfo.indicesSetByBlocks {
                    Memory.fastcopy(to: &buffer, index: indicesSet[0] / 4, count: indicesSet.count, value: fg.value)
                }
                var bg: PixelValue = PixelValue(background.red, background.green, background.blue, alpha: transparency)
                for indicesUnset in cellInfo.indicesUnsetByBlocks {
                    Memory.fastcopy(to: &buffer, index: indicesUnset[0] / 4, count: indicesUnset.count, value: bg.value)
                }
            }
            let end = Date()
            let elapsed = end.timeIntervalSince(start)
            print(String(format: "RANDOMIZE-SHORT-CIRCUIT-TIME: %.5f seconds", elapsed))
            return
        }

        var xyzzy_cellInfo: DebugCellInfo? = nil

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
                    xyzzy_cellInfo = PixelMap._write(&buffer, displayWidth, displayHeight,
                                    x: x, y: y, cellSize: cellSize,
                                    red: red, green: green, blue: blue,
                                    cellShape: cellShape, background: background, cellPadding: cellPadding, debug: true)
                    if (!PixelMap._randomizeCalledOnce) {
                        xyzzy_cellInfo!.indicesSetByBlocks = _consecutiveBlocks(xyzzy_cellInfo!.indicesSet)
                        xyzzy_cellInfo!.indicesUnsetByBlocks = _consecutiveBlocks(xyzzy_cellInfo!.indicesUnset)
                        PixelMap._cellsInfo.append(xyzzy_cellInfo!)
                    }
                }
            }
        }
        let end = Date()
        let elapsed = end.timeIntervalSince(start)
        print(String(format: "RANDOMIZE-TIME: %.5f seconds", elapsed))

        print("CELLS-INFO: \(PixelMap._cellsInfo.count)")
        if (xyzzy_cellInfo != nil) {
            print("CELL-INFO: \(xyzzy_cellInfo!.indicesSet.count) \(xyzzy_cellInfo!.indicesUnset.count)")
            print("CELL-INFO-BY-BLOCKS: \(xyzzy_cellInfo!.indicesSetByBlocks.count) \(xyzzy_cellInfo!.indicesUnsetByBlocks.count)")
        }

        PixelMap._randomizeCalledOnce = true
    }

    func write(x: Int, y: Int, red: UInt8, green: UInt8, blue: UInt8, transparency: UInt8 = 255, debug: Bool = false) {
        PixelMap._write(&self._buffer, self._displayWidth, self._displayHeight,
                        x: x, y: y, cellSize: self.cellSize,
                        red: red, green: green, blue: blue, transparency: transparency,
                        cellShape: self.cellShape, background: self.background,
                        cellPadding: self.cellPadding, debug: debug)
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
                cellPadding: Int = 0, debug: Bool = false) -> DebugCellInfo?
    {
        var cellInfo: DebugCellInfo? = debug ? DebugCellInfo() : nil

        var cellPaddingThickness: Int = 0
        if ((cellPadding > 0) && (cellSize >= 6 /*FixedSettings.pixelSizeMarginMin*/) && (cellShape != PixelShape.square)) {
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

        // print("CELL-WRITE-ITERATIONS: \(cellSize * cellSize) == \(cellSize)^2")
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

                let i = (iy * displayWidth + ix) * 4 /*ScreenDepth*/

                if i + 3 < buffer.count {
                    if shouldWrite {
                        if debug {
                            cellInfo!.indicesSet.append(i)
                        }
                        buffer[i] = red
                        buffer[i + 1] = green
                        buffer[i + 2] = blue
                        buffer[i + 3] = transparency
                    } else {
                        if debug {
                            cellInfo!.indicesUnset.append(i)
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
