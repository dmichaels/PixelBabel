import CoreGraphics
import Foundation
import SwiftUI

@MainActor
class PixelMap: ObservableObject {

    // This is mainly (was first created) for keeping track of the fourground/background buffer
    // indices for each cell, for the purpose of being able to write the values very fast using
    // block memory copy (see Memory.fastcopy). It is ASSUMED that the addBufferIndexFourground
    // and addBufferIndexBackground function are called with indices which are monotonically
    // increasing, and are not duplicated or anything weird; assumes called from the buffer
    // setting loop in the PixelMap._write method.
    //
    struct CellInfo {

        struct BlockInfo {
            var index: Int
            var count: Int
            var lastIndex: Int
        }

        let x: Int
        let y: Int
        var bufferIndicesFourground: [BlockInfo] = []
        var bufferIndicesBackground: [BlockInfo] = []
        static private let bufferBlockSize: Int = 4

        init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }

        mutating public func addBufferIndexFourground(_ index: Int) {
            CellInfo.addBufferIndex(index, indices: &self.bufferIndicesFourground)
        }

        mutating public func addBufferIndexBackground(_ index: Int) {
            CellInfo.addBufferIndex(index, indices: &self.bufferIndicesBackground)
        }

        private static func addBufferIndex(_ index: Int, indices: inout [BlockInfo]) {
            for i in stride(from: indices.count - 1, through: 0, by: -1) {
                if (index == (indices[i].lastIndex + CellInfo.bufferBlockSize)) {
                    indices[i].count += 1
                    indices[i].lastIndex = index
                    return
                }
            }
            indices.append(BlockInfo(index: index, count: 1, lastIndex: index))
        }

        public func writeBuffer(_ buffer: inout [UInt8], fg: PixelValue, bg: PixelValue? = nil) {
            for blockInfo in self.bufferIndicesFourground {
                Memory.fastcopy(to: &buffer, index: blockInfo.index / 4, count: blockInfo.count, value: fg.value)
            }
            if (bg != nil) {
                for blockInfo in self.bufferIndicesBackground {
                    Memory.fastcopy(to: &buffer, index: blockInfo.index / 4, count: blockInfo.count, value: bg!.value)
                }
            }
        }

        func sanityCheck() {
            return
            for blockInfoFG in self.bufferIndicesFourground {
                for blockInfoBG in self.bufferIndicesBackground {
                    let fgStart = blockInfoFG.index
                    let fgEnd = (blockInfoFG.index + (blockInfoFG.count * CellInfo.bufferBlockSize)) - 1
                    let bgStart = blockInfoBG.index
                    let bgEnd = (blockInfoBG.index + (blockInfoBG.count * CellInfo.bufferBlockSize)) - 1
                    // if ((fgStart > bgStart) || (fgEnd < bgStart)) {
                    if ((fgStart > bgEnd) || (fgEnd < bgStart) || (bgStart > fgEnd) || (bgEnd < fgStart)) {
                        // OK
                    }
                    else {
                        print("CELL-BLOCK-SANITY-CHECK-ERROR: \(fgStart) \(fgEnd) \(bgStart) \(bgEnd)")
                        print(blockInfoFG)
                        print(blockInfoBG)
                        // hm: 85668 86148 86148 86208
                    }
                }
            }
        }
    }

    static var _randomizeCalledOnce: Bool = false

    @Published var image: CGImage? = nil

    private var _displayWidth: Int = 0
    private var _displayHeight: Int = 0
    private var _displayChannelSize: Int = 0
    private var _displayScale: CGFloat = 0.0
    private var _displayScalingEnabled: Bool = true
    private var _cellSize: Int = 50 // 120 // 40
    private var _cellSizeUnscaled: Int = 50
    private var _cellPadding: Int = 2
    private var _cellShape: PixelShape = PixelShape.rounded
    private var _cellColorMode: ColorMode = ColorMode.color
    private var _cellBackground: PixelValue = PixelValue.dark
    private var _cellInfoCachingEnabled: Bool = true
    private var _bufferSize: Int = 0
    private var _buffer: [UInt8] = []
    private var _cellsInfo: [CellInfo] = []
    private let _colorSpace = CGColorSpaceCreateDeviceRGB()
    private let _bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue

    func configure(screen: ScreenInfo,
                   cellSize: Int = 50, // 120, // 40,
                   cellPadding: Int = 2,
                   cellShape: PixelShape = PixelShape.rounded,
                   cellColorMode: ColorMode = ColorMode.color,
                   cellBackground: PixelValue = PixelValue.dark,
                   displayScaling: Bool = true, // xyzzy
                   cellInfoCaching: Bool = true)
    {
        self._displayWidth = displayScaling ? screen.scaledWidth : screen.width
        self._displayHeight = displayScaling ? screen.scaledHeight : screen.height
        self._displayChannelSize = screen.channelSize
        self._displayScale = screen.scale
        self._displayScalingEnabled = displayScaling
        self._cellInfoCachingEnabled = cellInfoCaching

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

        self._initializeCellInfo()

        self.fill(with: PixelValue.light)
        self.update()
    }

    private func _initializeCellInfo() {
        self._cellsInfo = []
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
                    self._cellsInfo.append(cellInfo)
                    for debugCellInfo in self._cellsInfo {
                        debugCellInfo.sanityCheck()
                    }
                }
            }
        }
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

    public func locate(_ screenPoint: CGPoint) -> CGPoint {
        let screenX = max(Int(screenPoint.x), 0)
        let screenY = max(Int(screenPoint.y), 0)
        return CGPoint(x: Int(screenX / self._cellSizeUnscaled), y: Int(screenY / self._cellSizeUnscaled))
    }

    public func cell(_ x: Int, _ y: Int) -> CellInfo? {
        for cellInfo in self._cellsInfo {
            if ((cellInfo.x == x) && (cellInfo.y == y)) {
                return cellInfo
            }
        }
        return nil
    }

    public func onDrag(_ location: CGPoint) {
        let clocation = self.locate(location)  
        print("ON-DRAG: \(location)")
        let color = PixelValue.black
        print("ON-DRAG-A: \(color)")
        self.write(x: Int(clocation.x), y: Int(clocation.y), red: color.red, green: color.green, blue: color.blue)
        print("ON-DRAG-B")
        self.update()
        print("ON-DRAG-C")
    }

    public func onDragEnd(_ location: CGPoint) {
        print("ON-DRAG-END: \(location)")
        let color = PixelValue.random()
        self.write(x: Int(location.x), y: Int(location.y), red: color.red, green: color.green, blue: color.blue)
        self.update()
    }

    public func onTap(_ location: CGPoint) {
        print("ON-TAP: \(location)")
        self.randomize()
        self.update()
    }

    func fill(with pixel: PixelValue = PixelValue.dark) {
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
                            background: self.background,
                            cellsInfo: self._cellsInfo,
                            cellInfoCaching: self._cellInfoCachingEnabled)
    }

    static func _randomize(_ buffer: inout [UInt8], _ displayWidth: Int, _ displayHeight: Int,
                           width: Int, height: Int,
                           cellSize: Int,
                           cellColorMode: ColorMode,
                           cellShape: PixelShape,
                           cellPadding: Int,
                           background: PixelValue = PixelValue.dark,
                           cellsInfo: [CellInfo]? = nil,
                           cellInfoCaching: Bool = true)
    {
        let start = Date()

        if (PixelMap._randomizeCalledOnce && cellInfoCaching) {
            if (cellsInfo != nil) {
                print("RANDOMIZE-USING-CACHE")
                for cellInfo in cellsInfo! {
                    cellInfo.writeBuffer(&buffer, fg: PixelValue.random()) // , bg: PixelValue.white)
                }
            }
            let end = Date()
            let elapsed = end.timeIntervalSince(start)
            print(String(format: "RANDOMIZE-SHORT-CIRCUIT-TIME: %.5f seconds", elapsed))
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

        PixelMap._randomizeCalledOnce = true
    }

    func write(x: Int, y: Int, red: UInt8, green: UInt8, blue: UInt8, transparency: UInt8 = 255) {
        if (self._cellsInfo != nil) {
            if let cell = self.cell(x, y) {
                print("WRITE-CELL: \(x) \(y)")
                cell.writeBuffer(&self._buffer, fg: PixelValue(red, green, blue))
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
        if ((x < 0) || (y < 0)) {
            return nil
        }

        var cellInfo: CellInfo? = forCellInfo ? CellInfo(x: x, y: y) : nil

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

                if ((i >= 0) && ((i + 3) < buffer.count)) {
                    if shouldWrite {
                        if (cellInfo != nil) {
                            cellInfo!.addBufferIndexFourground(i)
                        }
                        buffer[i] = red
                        buffer[i + 1] = green
                        buffer[i + 2] = blue
                        buffer[i + 3] = transparency
                    } else {
                        if (cellInfo != nil) {
                            cellInfo!.addBufferIndexBackground(i)
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
