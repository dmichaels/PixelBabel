import CoreGraphics
import Foundation
import SwiftUI

@MainActor
class PixelMap: ObservableObject {

    struct Defaults {
        public static let displayWidth: Int = ScreenInfo.initialWidth
        public static let displayHeight: Int = ScreenInfo.initialHeight
        public static let displayScale: CGFloat = ScreenInfo.initialScale
        public static let displayScaling: Bool = true
        public static let displayTransparency: UInt8 = 255
        public static let cellSize: Int = 37 // 35
        public static let cellSizeNeat: Bool = true
        public static let cellPadding: Int = 2
        public static let cellBleeds: Bool = false
        public static let cellShape: PixelShape = PixelShape.rounded // PixelShape.rounded
        public static let cellColorMode: ColorMode = ColorMode.color
        public static let cellBackground: PixelValue = PixelValue.dark
        public static let cellAntialiasFade: Float = 0.6
        public static let cellRoundedRectangleRadius: Float = 0.25
        public static let cellLimitUpdate: Bool = true
        public static let cellCaching: Bool = true
    }

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
    private var _cellCaching: Bool = Defaults.cellCaching
    private var _bufferSize: Int = 0
    private var _buffer: [UInt8] = []
    private var _cells: Cells = Cells.null
    private let _colorSpace = CGColorSpaceCreateDeviceRGB()
    private let _bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue

    /*
    func rotateRight() {
        swap(&self._displayWidth, &self._displayHeight)
        self._cells.rotateRight()
    }
    */

    init() {
        print("PIXEL-MAP-CONSTRUCTOR!!!")
    }
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
                   cellCaching: Bool = Defaults.cellCaching)
    {
        print("PIXEL-MAP-CONFIGURE!!!")
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
        self._cellCaching = cellCaching
        self._bufferSize = self._displayWidth * self._displayHeight * ScreenInfo.depth
        self._buffer = [UInt8](repeating: 0, count: self._bufferSize)

        // let neatCells = PixelMap._preferredCellSizes(unscaled(self._displayWidth), unscaled(self._displayHeight))
        let neatCells = Cells.preferredCellSizes(unscaled(self._displayWidth), unscaled(self._displayHeight))
        /*
        print("NEAT-CELL-SIZES-US:")
        for neatCell in neatCells {
            print("NEAT-CELL-US: \(neatCell.cellSize) | \(neatCell.displayWidth) \(neatCell.displayHeight) | \(unscaled(self._displayWidth) - neatCell.displayWidth) \(unscaled(self._displayHeight) - neatCell.displayHeight)")
        }
        */
        if (cellSizeNeat) {
            if let neatCell = Cells.closestPreferredCellSize(in: neatCells, to: unscaled(self._cellSize)) {
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

        self._cells = self._initializeCells()
        self.fill(with: PixelValue.dark)
    }

    private func _initializeCells() -> Cells {
        var cells = Cells(displayWidth: self._displayWidth,
                          displayHeight: self._displayHeight,
                          displayScale: self._displayScale,
                          displayScaling: self._displayScaling,
                          cellSize: self._cellSize)
        if (self._cellCaching) {
            PixelMap._write(&self._buffer,
                            self._displayWidth, self._displayHeight,
                            x: 0, y: 0,
                            cellSize: self.cellSize,
                            red: 0, green: 0, blue: 0,
                            cellShape: self.cellShape,
                            cellPadding: self.cellPadding,
                            background: self.background,
                            cells: cells)
        }
        for y in 0..<self.height {
            for x in 0..<self.width {
                cells.defineCell(x: x, y: y)
            }
        }
        return cells
    }

    var displayOrientation: UIDeviceOrientation {
        get { self._cells.displayOrientation }
        set { self._cells.displayOrientation = newValue }
    }

    public var displayWidth: Int {
        self._displayWidth
    }

    public var displayHeight: Int {
        self._displayHeight
    }

    public var displayScale: CGFloat {
        self._displayScaling ? self._displayScale : 1
    }

    private func scaled(_ value: Int) -> Int {
        self._displayScaling ? Int(round(CGFloat(value) * self.displayScale)) : value
    }

    public func unscaled(_ value: Int) -> Int {
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

    public func onDrag(_ location: CGPoint, orientation: UIDeviceOrientation = UIDeviceOrientation.portrait, previousOrientation: UIDeviceOrientation = UIDeviceOrientation.portrait) {
        let normalizedLocation = self.normalizedLocation(location, orientation: orientation, previousOrientation: previousOrientation)
        if let cell = self._cells.cell(normalizedLocation) {
        // if let cell = self._cells.cell(location) {
            let color = PixelValue(255, 0, 0)
            self.write(x: cell.x, y: cell.y, red: color.red, green: color.green, blue: color.blue)
        }
        return
    }

    public func onDragEnd(_ location: CGPoint, orientation: UIDeviceOrientation = UIDeviceOrientation.portrait, previousOrientation: UIDeviceOrientation = UIDeviceOrientation.portrait) {
        let normalizedLocation = self.normalizedLocation(location, orientation: orientation, previousOrientation: previousOrientation)
        let color = PixelValue.random()
        self.write(x: Int(normalizedLocation.x), y: Int(normalizedLocation.y), red: color.red, green: color.green, blue: color.blue)
        // self.write(x: Int(location.x), y: Int(location.y), red: color.red, green: color.green, blue: color.blue)
    }

    public func onTap(_ location: CGPoint) {
        print("ON-TAP: \(location)")
        if let cell = self._cells.cell(location) {
            print("TAP: \(location) -> (\(cell.x), \(cell.y))")
            // if cell.x == 2 && cell.y == 2 {
                // self.rotateRight()
            // }
            self.randomize()
        }
    }

    public func locate(_ location: CGPoint) -> Point? {
        return self._cells.locate(location)
    }

    public func locate2_bak(_ location: CGPoint,
                         orientation: UIDeviceOrientation = UIDeviceOrientation.portrait,
                         previousOrientation: UIDeviceOrientation = UIDeviceOrientation.portrait) -> Point? {
        let x, y: CGFloat
        switch orientation {
        case .portrait:
            x = location.x
            y = location.y
            print("NEW-LOCATE-PO: \(location) -> \(x), \(y) | iw: \(unscaled(self._displayWidth)) ih: \(unscaled(self._displayHeight))")
        case .portraitUpsideDown:
            if previousOrientation.isLandscape {
                x = location.y
                y = CGFloat(unscaled(self._displayHeight)) - 1 - location.x
            }
            else {
                x = location.x
                y = location.y
            }
            print("NEW-LOCATE-UD: \(location) -> \(x), \(y) | iw: \(unscaled(self._displayWidth)) ih: \(unscaled(self._displayHeight))")
        case .landscapeRight:
            x = location.y
            y = CGFloat(unscaled(self._displayHeight)) - 1 - location.x
            print("NEW-LOCATE-LR: \(location) -> \(x), \(y) | iw: \(unscaled(self._displayHeight)) ih: \(unscaled(self._displayHeight))")
        case .landscapeLeft:
            x = CGFloat(unscaled(self._displayWidth)) - 1 - location.y
            y = location.x
            print("NEW-LOCATE-LL: \(location) -> \(x), \(y) | iw: \(unscaled(self._displayWidth)) ih: \(unscaled(self._displayHeight))")
        default:
            x = location.x
            y = location.y
            print("NEW-LOCATE-DEFAULT: \(location) -> \(x), \(y) | iw: \(unscaled(self._displayWidth)) ih: \(unscaled(self._displayHeight))")
        }
        let normalizedLocation = CGPoint(x: x, y: y)
        print("NEW-LOCATE-NORMALIZED: \(location) \(normalizedLocation)")
        return self._cells.locate(normalizedLocation)
    }

    public func locate2(_ location: CGPoint,
                         orientation: UIDeviceOrientation = UIDeviceOrientation.portrait,
                         previousOrientation: UIDeviceOrientation = UIDeviceOrientation.portrait) -> Point? {
        let normalizedLocation = self.normalizedLocation(location, orientation: orientation, previousOrientation: previousOrientation)
        print("NEW-LOCATE-NORMALIZED: \(location) \(normalizedLocation)")
        return self._cells.locate(normalizedLocation)
    }

    public func normalizedLocation(_ location: CGPoint,
                                   orientation: UIDeviceOrientation = UIDeviceOrientation.portrait,
                                   previousOrientation: UIDeviceOrientation = UIDeviceOrientation.portrait) -> CGPoint {
        let x, y: CGFloat
        switch orientation {
        case .portrait:
            x = location.x
            y = location.y
            print("NEW-LOCATE-PO: \(location) -> \(x), \(y) | iw: \(unscaled(self._displayWidth)) ih: \(unscaled(self._displayHeight))")
        case .portraitUpsideDown:
            if previousOrientation.isLandscape {
                x = location.y
                y = CGFloat(unscaled(self._displayHeight)) - 1 - location.x
            }
            else {
                x = location.x
                y = location.y
            }
            print("NEW-LOCATE-UD: \(location) -> \(x), \(y) | iw: \(unscaled(self._displayWidth)) ih: \(unscaled(self._displayHeight))")
        case .landscapeRight:
            x = location.y
            y = CGFloat(unscaled(self._displayHeight)) - 1 - location.x
            print("NEW-LOCATE-LR: \(location) -> \(x), \(y) | iw: \(unscaled(self._displayHeight)) ih: \(unscaled(self._displayHeight))")
        case .landscapeLeft:
            x = CGFloat(unscaled(self._displayWidth)) - 1 - location.y
            y = location.x
            print("NEW-LOCATE-LL: \(location) -> \(x), \(y) | iw: \(unscaled(self._displayWidth)) ih: \(unscaled(self._displayHeight))")
        default:
            x = location.x
            y = location.y
            print("NEW-LOCATE-DEFAULT: \(location) -> \(x), \(y) | iw: \(unscaled(self._displayWidth)) ih: \(unscaled(self._displayHeight))")
        }
        return CGPoint(x: x, y: y)
    }

    func fill(with pixel: PixelValue = PixelValue.dark) {
        for y in 0..<self._displayHeight {
            for x in 0..<self._displayWidth {
                let i = (y * self._displayWidth + x) * ScreenInfo.depth
                self._buffer[i + 0] = pixel.red
                self._buffer[i + 1] = pixel.green
                self._buffer[i + 2] = pixel.blue
                self._buffer[i + 3] = pixel.alpha
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
                space: self._colorSpace,
                bitmapInfo: self._bitmapInfo
            ) {
                // image = context.makeImage()
                let start = CFAbsoluteTimeGetCurrent()
                image = context.makeImage()
                let end = CFAbsoluteTimeGetCurrent()
                print(String(format: "MAKE-IMAGE-TIME: %.5f ms", (end - start) * 1000))
                print("MAKE-IMAGE-SIZE: \(image!.width) \(image!.height)")
            }
        }
        return image
    }

    func randomize() {
        PixelMap._randomize(&self._buffer,
                            self._displayWidth, self._displayHeight,
                            width: self.width, height: self.height,
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
                           cells: Cells? = nil)
    {
        let start = Date()

        if ((cells != nil) && cells!.caching) {
            for cell in cells!.cells {
                cell.write(&buffer, foreground: PixelValue.random(), background: background, limit: Defaults.cellLimitUpdate)
            }
            let end = Date()
            let elapsed = end.timeIntervalSince(start)
            print(String(format: "NEW-RANDOMIZE-OPTIMIZED-TIME: %.5f seconds", elapsed))
            return
        }

        for y in 0..<height {
            for x in 0..<width {
                if (cellColorMode == ColorMode.monochrome) {
                    let value: UInt8 = UInt8.random(in: 0...1) * 255
                    PixelMap._write(&buffer,
                                    displayWidth, displayHeight,
                                    x: x, y: y,
                                    cellSize: cellSize,
                                    red: value, green: value, blue: value,
                                    cellShape: cellShape,
                                    cellPadding: cellPadding,
                                    background: background)
                }
                else if (cellColorMode == ColorMode.grayscale) {
                    let value = UInt8.random(in: 0...255)
                    PixelMap._write(&buffer,
                                    displayWidth, displayHeight,
                                    x: x, y: y,
                                    cellSize: cellSize,
                                    red: value, green: value, blue: value,
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
                                    displayWidth, displayHeight,
                                    x: x, y: y,
                                    cellSize: cellSize,
                                    red: red, green: green, blue: blue,
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
        if let cell = self._cells.cell(x, y) {
            cell.write(&self._buffer, foreground: PixelValue(red, green, blue), background: self.background, limit: Defaults.cellLimitUpdate)
        }
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
                       cells: Cells? = nil)
    {
        if ((x < 0) || (y < 0)) {
            return
        }

        var cellPaddingThickness = 0
        if ((cellPadding > 0) && (cellSize >= 6) && (cellShape != .square)) {
            cellPaddingThickness = cellPadding
        }

        let startX = x * cellSize
        let startY = y * cellSize
        let endX = (startX + cellSize)
        let endY = (startY + cellSize)
        let adjustedScale = cellSize - 2 * cellPaddingThickness
        let centerX = Float(startX + cellSize / 2)
        let centerY = Float(startY + cellSize / 2)
        let circleRadius = Float(adjustedScale) / 2.0
        let radiusSquared = circleRadius * circleRadius
        let fadeRange: Float = 0.6  // smaller -> smoother

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
                    if ((dx >= cellPaddingThickness) && (dx < cellSize - cellPaddingThickness) &&
                        (dy >= cellPaddingThickness) && (dy < cellSize - cellPaddingThickness)) {
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

                let i = (iy * displayWidth + ix) * 4
                if i >= 0 && i + 3 < buffer.count {
                    let alpha = UInt8(Float(transparency) * coverage)
                    if coverage > 0 {
                        if (cells != nil) {
                            cells!.addBufferItem(i, foreground: true, blend: coverage)
                        }
                        else {
                            buffer[i]     = Cells.blend(red, background.red, amount: coverage)
                            buffer[i + 1] = Cells.blend(green, background.green, amount: coverage)
                            buffer[i + 2] = Cells.blend(blue, background.blue, amount: coverage)
                            buffer[i + 3] = transparency
                        }

                    } else {
                        if (cells != nil) {
                            cells!.addBufferItem(i, foreground: false)
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
    }
}
