import CoreGraphics
import Foundation
import SwiftUI
import Utils

@MainActor
class CellGrid: ObservableObject {

    struct Defaults {
        public static let displayWidth: Int = ScreenInfo.initialWidth
        public static let displayHeight: Int = ScreenInfo.initialHeight
        public static let displayScale: CGFloat = ScreenInfo.initialScale
        public static let displayScaling: Bool = true
        public static let displayTransparency: UInt8 = 255
        public static let cellSize: Int = 43 // 32 // 8 // 83 // 43 // 37 // 35
        public static let cellSizeNeat: Bool = true
        public static let cellPadding: Int = 2
        public static let cellBleeds: Bool = false
        public static let cellShape: CellShape = CellShape.rounded // CellShape.rounded
        public static let cellColorMode: CellColorMode = CellColorMode.color
        public static let cellBackground: CellColor = CellColor.dark
        public static let cellAntialiasFade: Float = 0.6
        public static let cellRoundedRectangleRadius: Float = 0.25
        public static var cellPreferredSizeMarginMax: Int   = 30
        public static let cellLimitUpdate: Bool = true
        public static let cellCaching: Bool = true
        public static let colorSpace = CGColorSpaceCreateDeviceRGB()
        public static let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
    }

    private var _displayWidth: Int = ScreenInfo.initialWidth
    private var _displayHeight: Int = ScreenInfo.initialHeight
    private var _displayScale: CGFloat = ScreenInfo.initialScale
    private var _displayScaling: Bool = Defaults.displayScaling
    private var _cellSize: Int = Defaults.cellSize
    private var _cellPadding: Int = Defaults.cellPadding
    private var _cellBleeds: Bool = Defaults.cellBleeds
    private var _cellShape: CellShape = Defaults.cellShape
    private var _cellColorMode: CellColorMode = Defaults.cellColorMode
    private var _cellBackground: CellColor = Defaults.cellBackground
    private var _cellAntialiasFade: Float = Defaults.cellAntialiasFade
    private var _cellRoundedRectangleRadius: Float = Defaults.cellRoundedRectangleRadius
    private var _cellPreferredSizeMarginMax: Int = Defaults.cellPreferredSizeMarginMax
    private var _cellCaching: Bool = Defaults.cellCaching
    private var _cellLimitUpdate: Bool = Defaults.cellLimitUpdate
    private var _cells: Cells? = nil
    private var _cellFactory: Cells.CellFactory?
    private var _dragCell: Cell? = nil

    internal var _buffer: [UInt8] = []

    init(cellFactory: Cells.CellFactory? = nil) {
        self._cellFactory = cellFactory
        print("PIXELMAP-CONSTRUCTOR!!!")
    }

    func configure(screen: ScreenInfo,
                   displayWidth: Int = Defaults.displayWidth,
                   displayHeight: Int = Defaults.displayHeight,
                   cellSize: Int = Defaults.cellSize,
                   cellSizeNeat: Bool = Defaults.cellSizeNeat,
                   cellPadding: Int = Defaults.cellPadding,
                   cellBleeds: Bool = Defaults.cellBleeds,
                   cellShape: CellShape = Defaults.cellShape,
                   cellColorMode: CellColorMode = Defaults.cellColorMode,
                   cellBackground: CellColor = Defaults.cellBackground,
                   displayScaling: Bool = Defaults.displayScaling,
                   cellCaching: Bool = Defaults.cellCaching)
    {
        print("PIXELMAP-CONFIGURE!!!")
        self._displayScale = screen.scale
        self._displayScaling = [CellShape.square, CellShape.inset].contains(cellShape) ? false : displayScaling
        self._displayWidth = scaled(displayWidth)
        self._displayHeight = scaled(displayHeight)

        self._cellSize = scaled(cellSize)
        self._cellPadding = scaled(cellPadding)
        self._cellBleeds = cellBleeds
        self._cellShape = cellShape
        self._cellColorMode = cellColorMode
        self._cellBackground = cellBackground
        self._cellCaching = cellCaching

        let bufferSize = self._displayWidth * self._displayHeight * ScreenInfo.depth
        self._buffer = [UInt8](repeating: 0, count: bufferSize)

        let neatCells = Cells.preferredCellSizes(unscaled(self._displayWidth), unscaled(self._displayHeight), cellPreferredSizeMarginMax: self._cellPreferredSizeMarginMax)
        // print("NEAT-CELL-SIZES-US:")
        // for neatCell in neatCells {
        //     print("NEAT-CELL-US: \(neatCell.cellSize) | \(neatCell.displayWidth) \(neatCell.displayHeight) | \(unscaled(self._displayWidth) - neatCell.displayWidth) \(unscaled(self._displayHeight) - neatCell.displayHeight)")
        // }
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
        print("BUFFER-SIZE:            \(bufferSize)")

        self._cells = self._configureCells()

        // self.fill(with: self._cellBackground)
    }

    private func _configureCells() -> Cells {
        var cells = Cells(parent: self,
                          displayWidth: self._displayWidth,
                          displayHeight: self._displayHeight,
                          displayScale: self._displayScale,
                          displayScaling: self._displayScaling,
                          cellSize: self._cellSize,
                          cellFactory: self._cellFactory)
        if (self._cellCaching) {
            CellGrid._write(&self._buffer,
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

    public var displayWidth: Int {
        self._displayWidth
    }

    public var displayHeight: Int {
        self._displayHeight
    }

    public var displayWidthUnscaled: Int {
        unscaled(self._displayWidth)
    }

    public var displayHeightUnscaled: Int {
        unscaled(self._displayHeight)
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

    public var cellShape: CellShape {
        self._cellShape
    }

    public var cellColorMode: CellColorMode {
        self._cellColorMode
    }

    public var background: CellColor {
        self._cellBackground
    }

    public func onDrag(_ location: CGPoint) {
        if let cell = self._cells?.cell(location) {
            if ((self._dragCell == nil) || (self._dragCell!.location != cell.location)) {
                let color = cell.foreground.tintedRed(by: 0.60)
                // self.write(x: cell.x, y: cell.y, red: color.red, green: color.green, blue: color.blue)
                self.writeCell(cell, color)
                self._dragCell = cell
            }
            // let color = PixelValue(255, 255, 0)
            // self.write(x: cell.x, y: cell.y, red: color.red, green: color.green, blue: color.blue)
        }
    }

    public func onDragEnd(_ location: CGPoint) {
        self._dragCell = nil
        let color = CellColor.random()
        self.write(x: Int(location.x), y: Int(location.y), red: color.red, green: color.green, blue: color.blue,
                   limit: self._cellLimitUpdate)
    }

    public func onTap(_ location: CGPoint) {
        if let cell = self._cells?.cell(location) {
            self.randomize()
        }
    }

    public func locate(_ location: CGPoint) -> CellGridPoint? {
        return self._cells?.locate(location)
    }

    func fill(with color: CellColor, limit: Bool = true) {
        if let cells = self._cells {
            if (cells.caching) {
                for cell in cells.cells {
                    print("OKOKOKOKOKOKOK: \(limit)")
                    cell.write(&self._buffer, foreground: color, background: self._cellBackground, limit: limit)
                    // cell.write(foreground: color, background: self._cellBackground, limit: limit) // xyzzy
                }
            }
            else {
                for cell in cells.cells {
                    self.writeCell(cell, color, limit: limit)
                }
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
                space: Defaults.colorSpace,
                bitmapInfo: Defaults.bitmapInfo
            ) {
                let start = CFAbsoluteTimeGetCurrent()
                image = context.makeImage()
                let end = CFAbsoluteTimeGetCurrent()
                print(String(format: "MAKE-IMAGE-TIME: %.5f ms | \(image!.width) \(image!.height)", (end - start) * 1000))
            }
        }
        return image
    }

    func randomize() {
        CellGrid._randomize(&self._buffer,
                            self._displayWidth, self._displayHeight,
                            width: self.width, height: self.height,
                            cellSize: self.cellSize,
                            cellColorMode: self.cellColorMode,
                            cellShape: self.cellShape,
                            cellPadding: self.cellPadding,
                            cellLimitUpdate: self._cellLimitUpdate,
                            background: self.background,
                            cells: self._cells)
    }

    static func _randomize(_ buffer: inout [UInt8],
                           _ displayWidth: Int,
                           _ displayHeight: Int,
                           width: Int, height: Int,
                           cellSize: Int,
                           cellColorMode: CellColorMode,
                           cellShape: CellShape,
                           cellPadding: Int,
                           cellLimitUpdate: Bool,
                           background: CellColor,
                           cells: Cells? = nil)
    {
        let start = Date()

        if ((cells != nil) && cells!.caching) {
            for cell in cells!.cells {
                cell.write(&buffer, foreground: CellColor.random(), background: background, limit: cellLimitUpdate)
                // cell.write(foreground: CellColor.random(), background: background, limit: cellLimitUpdate) // xyzzyxyzzy
            }
            let end = Date()
            let elapsed = end.timeIntervalSince(start)
            print(String(format: "CACHED-RANDOMIZE-TIME: %.5f sec | \(cellLimitUpdate)", elapsed))
            return
        }

        for y in 0..<height {
            for x in 0..<width {
                if (cellColorMode == CellColorMode.monochrome) {
                    let value: UInt8 = UInt8.random(in: 0...1) * 255
                    CellGrid._write(&buffer,
                                    displayWidth, displayHeight,
                                    x: x, y: y,
                                    cellSize: cellSize,
                                    red: value, green: value, blue: value,
                                    cellShape: cellShape,
                                    cellPadding: cellPadding,
                                    background: background)
                }
                else if (cellColorMode == CellColorMode.grayscale) {
                    let value = UInt8.random(in: 0...255)
                    CellGrid._write(&buffer,
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
                    CellGrid._write(&buffer,
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
        print(String(format: "RANDOMIZE-TIME: %.5f sec", elapsed))
    }

    func writeCell(_ cell: Cell, _ color: CellColor, limit: Bool = true) {
        cell.write(&self._buffer, foreground: color, background: self.background, limit: limit)
        // cell.write(foreground: color, background: self.background, limit: limit) // xyzzy
    }

    func write(x: Int, y: Int, red: UInt8, green: UInt8, blue: UInt8, transparency: UInt8 = CellGrid.Defaults.displayTransparency, limit: Bool = true) {
        if let cell = self._cells?.cell(x, y) {
            cell.write(&self._buffer, foreground: CellColor(red, green, blue), background: self.background, limit: limit)
            // cell.write(foreground: CellColor(red, green, blue), background: self.background, limit: limit) // xyzzy
        }
    }

    static func _write(_ buffer: inout [UInt8],
                       _ displayWidth: Int, _ displayHeight: Int,
                       x: Int, y: Int,
                       cellSize: Int,
                       red: UInt8, green: UInt8, blue: UInt8,
                       transparency: UInt8 = CellGrid.Defaults.displayTransparency,
                       cellShape: CellShape = .rounded,
                       cellPadding: Int = 0,
                       background: CellColor,
                       cells: Cells? = nil)
    {
        if ((x < 0) || (y < 0)) {
            return
        }

        var cellPaddingThickness: Int = 0
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
