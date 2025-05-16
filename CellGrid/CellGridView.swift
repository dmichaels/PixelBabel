import Foundation
import SwiftUI
import Utils

// A main purpose of this (as first created) is for keeping track of the backing pixel buffer
// indices for the (canonical) cell; for the purpose of being able to write the values very fast
// using block memory copy (Memory.fastcopy). It is ASSUMED that the BufferBlocks.append function
// is called with indices which are monotonically increasing, and are not duplicated or out of order
// or anything weird; assume called from the buffer setting loop in the PixelMap._write method.
//
// Note on terminology: We say "cell-grid" to mean the virtual grid of all cells in existence,
// and "grid-view" to mean the viewable window (image) in which is a subset of the cell-grid.
// We say "point" to mean a pixel coordinate (coming from a gesture) which is not scaled.
// We say "location" to mean a coordinate cell-based coordinate on the cell-grid or grid-view;

@MainActor
class CellGridView {

    struct Defaults {
        public static var cellPaddingMax: Int = 8
        public static var cellSizeMax: Int = 100
        public static var cellSizeInnerMin: Int = 6

        public static var preferredSizeMarginMax: Int = 30
        public static let cellAntialiasFade: Float = 0.6  // smaller is smoother
        public static let cellRoundedRectangleRadius: Float = 0.25
    }

    private var _viewWidth: Int = 0
    private var _viewHeight: Int = 0
    private var _viewWidthExtra: Int = 0
    private var _viewHeightExtra: Int = 0
    private var _viewColumns: Int = 0
    private var _viewRows: Int = 0
    private var _viewColumnsExtra: Int = 0
    private var _viewRowsExtra: Int = 0
    private var _viewCellEndX: Int = 0
    private var _viewCellEndY: Int = 0
    private var _viewBackground: CellColor = CellColor.black
    private var _viewTransparency: UInt8 = 0
    private var _viewScaling: Bool = true

    private var _cellSize: Int = 0
    private var _cellSizeTimesViewWidth: Int = 0
    private var _cellPadding: Int = 0
    private var _cellShape: CellShape = .rounded

    private var _gridColumns: Int = 0
    private var _gridRows: Int = 0
    private var _gridCellEndX: Int = 0
    private var _gridCellEndY: Int = 0
    private var _gridCellFactory: Cell.Factory? = nil
    private var _gridCells: [Cell] = []

    // These change based on moving/shifting the cell-grid around the grid-view.
    //
    private var _shiftCellX: Int = 0
    private var _shiftCellY: Int = 0
    private var _shiftX: Int = 0
    private var _shiftY: Int = 0

    private var _buffer: [UInt8] = []
    private var _bufferBlocks: CellGridView.BufferBlocks = BufferBlocks(width: 0)

    init(viewWidth: Int,
         viewHeight: Int,
         viewBackground: CellColor,
         viewTransparency: UInt8 = CellColor.OPAQUE,
         viewScaling: Bool,
         cellSize: Int,
         cellPadding: Int,
         cellFit: Bool,
         cellShape: CellShape,
         gridColumns: Int,
         gridRows: Int,
         gridCellFactory: Cell.Factory? = nil,
         gridCells: [Cell]? = nil)
    {
        let scaling: Bool = [CellShape.square, CellShape.inset].contains(cellShape) ? false : viewScaling

        func scaled(_ value: Int) -> Int {
            return Screen.shared.scaled(value, scaling: scaling)
        }

        func unscaled(_ value: Int) -> Int {
            return Screen.shared.unscaled(value, scaling: scaling)
        }

        func defineGridCells(gridColumns: Int, gridRows: Int,
                             gridCellFactory: Cell.Factory?, foreground: CellColor) -> [Cell]
        {
            var gridCells: [Cell] = []
            for y in 0..<gridRows {
                for x in 0..<gridColumns {
                    gridCells.append(gridCellFactory?(self, x, y, foreground) ??
                                     Cell(parent: self, x: x, y: y, foreground: foreground))
                }
            }
            return gridCells
        }

        let preferredSize = CellGridView.preferredSize(viewWidth: viewWidth, viewHeight: viewHeight,
                                                       cellSize: cellSize, enabled: cellFit)

        self.configure(cellSize: preferredSize.cellSize,
                       cellPadding: cellPadding,
                       cellShape: cellShape,
                       viewWidth: preferredSize.viewWidth,
                       viewHeight: preferredSize.viewHeight,
                       viewBackground: viewBackground,
                       viewTransparency: viewTransparency,
                       viewScaling: scaling)

        self._gridColumns = gridColumns > 0 ? gridColumns : self._viewColumns
        self._gridRows = gridRows > 0 ? gridRows : self._viewRows
        self._gridCellEndX = self._gridColumns - 1
        self._gridCellEndY = self._gridRows - 1
        self._gridCellFactory = gridCellFactory
        self._gridCells = gridCells ?? defineGridCells(gridColumns: self._gridColumns,
                                                       gridRows: self._gridRows,
                                                       gridCellFactory: self._gridCellFactory,
                                                       foreground: CellGrid.Defaults.cellForeground)
        self._shiftCellX = 0
        self._shiftCellY = 0
        self._shiftX = 0
        self._shiftY = 0

        // self.printSizes(viewWidthInit: viewWidth, viewHeightInit: viewHeight, cellSizeInit: cellSize, cellFitInit: cellFit)
    }

    private func configure(cellSize: Int,
                           cellPadding: Int,
                           cellShape: CellShape,
                           viewWidth: Int,
                           viewHeight: Int,
                           viewBackground: CellColor,
                           viewTransparency: UInt8,
                           viewScaling: Bool)
    {
        var cellPadding: Int = cellPadding.clamped(0...Defaults.cellPaddingMax)
        var cellSize = cellSize.clamped(Defaults.cellSizeInnerMin + (cellPadding * 2)...Defaults.cellSizeMax)

        self._viewScaling = [CellShape.square, CellShape.inset].contains(cellShape) ? false : viewScaling

        self._viewWidth = self.scaled(viewWidth)
        self._viewHeight = self.scaled(viewHeight)
        self._cellSize = self.scaled(cellSize)
        self._cellSizeTimesViewWidth = self._cellSize * self._viewWidth
        self._cellPadding = self.scaled(cellPadding)

        self._viewColumns = self._viewWidth / self._cellSize
        self._viewRows = self._viewHeight / self._cellSize
        self._viewCellEndX = self._viewColumns - 1
        self._viewCellEndY = self._viewRows - 1
        self._viewWidthExtra = self._viewWidth % self._cellSize
        self._viewHeightExtra = self._viewHeight % self._cellSize
        self._viewColumnsExtra = (self._viewWidthExtra > 0) ? 1 : 0
        self._viewRowsExtra = (self._viewHeightExtra > 0) ? 1 : 0

        self._buffer = Memory.allocate(self._viewWidth * self._viewHeight * Screen.depth)
        self._bufferBlocks = BufferBlocks.createBufferBlocks(bufferSize: self._buffer.count,
                                                             viewWidth: self._viewWidth,
                                                             viewHeight: self._viewHeight,
                                                             cellSize: self._cellSize,
                                                             cellPadding: self._cellPadding,
                                                             cellShape: self._cellShape,
                                                             cellTransparency: self._viewTransparency)
        // self.printSizes()
    }

    public var viewScale: CGFloat {
        Screen.shared.scale(scaling: self._viewScaling)
    }

    public var viewScaling: Bool {
        get { self._viewScaling }
        set {
            if (newValue != self._viewScaling) {
                let currentShift: CellLocation = self.shiftedBy
                self.configure(cellSize: self.unscaled(self._cellSize),
                               cellPadding: self.unscaled(self._cellPadding),
                               cellShape: self._cellShape,
                               viewWidth: self.unscaled(self._viewWidth),
                               viewHeight: self.unscaled(self._viewHeight),
                               viewBackground: self._viewBackground,
                               viewTransparency: self._viewTransparency,
                               viewScaling: newValue)
                self.shift(shiftx: currentShift.x, shifty: currentShift.y)
            }
        }
    }

    internal func scaled(_ value: Int) -> Int {
        return Screen.shared.scaled(value, scaling: self._viewScaling)
    }

    internal func unscaled(_ value: Int) -> Int {
        return Screen.shared.unscaled(value, scaling: self._viewScaling)
    }

    public func shift(shiftx: Int = 0, shifty: Int = 0)
    {
        let debugStart = Date()

        // Normalize the given pixel level shift to cell and pixel level.

        var shiftX: Int = self.scaled(shiftx), shiftCellX: Int
        var shiftY: Int = self.scaled(shifty), shiftCellY: Int

        if (shiftX != 0) {
            shiftCellX = shiftX / self._cellSize
            if (shiftCellX != 0) {
                shiftX = shiftX % self._cellSize
            }
        }
        else {
            shiftCellX = 0
        }
        if (shiftY != 0) {
            shiftCellY = shiftY / self._cellSize
            if (shiftCellY != 0) {
                shiftY = shiftY % self._cellSize
            }
        }
        else {
            shiftCellY = 0
        }

        // Restrict the shift to min/max; support different rules:
        //
        // - Disallow the left-most cell of the cell-grid being right-shifted past the right-most
        //   position of the grid-view, and the right-most cell of the grid-view being left-shifted
        //   past the left-most position of the grid-view; similarly for the vertical.
        //
        // - TODO
        //   Disallow the left-most cell of the cell-grid being right-shifted past the left-most
        //   position of the grid-view, and the right-most cell of the cell-grid being left-shifted
        //   past the right-most position of the grid-view; similarly for the vertical.

        func restrictShift(shiftCellXY: inout Int, shiftXY: inout Int, viewCellEndXY: Int,
                           viewSizeExtra: Int, viewSize: Int, gridCellEndXY: Int) {
            if (shiftCellXY >= viewCellEndXY) {
                if (viewSizeExtra > 0) {
                    let totalShift = (shiftCellXY * self._cellSize) + shiftXY
                    if ((viewSize - totalShift) <= self._cellSize) {
                        let adjusted = viewSize - self._cellSize
                        shiftCellXY = adjusted / self._cellSize
                        shiftXY = adjusted % self._cellSize
                    }
                } else {
                    shiftCellXY = viewCellEndXY
                    shiftXY = 0
                }
            } else if (-shiftCellXY >= gridCellEndXY) {
                shiftCellXY = -gridCellEndXY
                shiftXY = 0
            }
        }

        restrictShift(shiftCellXY: &shiftCellX,
                      shiftXY: &shiftX,
                      viewCellEndXY: self._viewCellEndX,
                      viewSizeExtra: self._viewWidthExtra,
                      viewSize: self._viewWidth,
                      gridCellEndXY: self._gridCellEndX)
        restrictShift(shiftCellXY: &shiftCellY,
                      shiftXY: &shiftY,
                      viewCellEndXY: self._viewCellEndY,
                      viewSizeExtra: self._viewHeightExtra,
                      viewSize: self._viewHeight,
                      gridCellEndXY: self._gridCellEndY)

        // Update the shift related values for the view.

        self._shiftCellX = shiftCellX
        self._shiftCellY = shiftCellY
        self._shiftX = shiftX
        self._shiftY = shiftY

        self._viewColumnsExtra = (self._shiftX != 0 ? 1 : 0)
        if (self._shiftX > 0) {
            if (self._viewWidthExtra > self._shiftX) {
                self._viewColumnsExtra += 1
            }
        }
        else if (self._shiftX < 0) {
            if (self._viewWidthExtra > (self._cellSize + self._shiftX)) {
                self._viewColumnsExtra += 1
            }
        }
        else if (self._viewWidthExtra > 0) {
            self._viewColumnsExtra += 1
        }
        self._viewRowsExtra = (self._shiftY != 0 ? 1 : 0)
        if (self._shiftY > 0) {
            if (self._viewHeightExtra > self._shiftY) {
                self._viewRowsExtra += 1
            }
        }
        else if (self._shiftY < 0) {
            if (self._viewHeightExtra > (self._cellSize + self._shiftY)) {
                self._viewRowsExtra += 1
            }
        }
        else if (self._viewHeightExtra > 0) {
            self._viewRowsExtra += 1
        }

        // Now actually write the cells to the view.

        for vy in 0...self._viewCellEndY + self._viewRowsExtra {
            for vx in 0...self._viewCellEndX + self._viewColumnsExtra {
                self.writeCell(viewCellX: vx, viewCellY: vy)
            }
        }

        print(String(format: "SHIFTT> %.5fs [\(shiftx),\(shifty)] | blocks-memory: \(self._bufferBlocks.memoryUsageBytes)", Date().timeIntervalSince(debugStart)))
    }

    // Draws at the given grid view cell location (viewCellX, viewCellY), the grid cell currently corresponding
    // to that location, taking into account the current shiftCellX/Y and shiftX/Y values, i.e. the cell and
    // pixel level based shift values, negative meaning to shift the grid cell left or up, and positive
    // meaning to shift the grid cell right or down.
    //
    public func writeCell(viewCellX: Int, viewCellY: Int)
    {
        // Get the left/right truncation amount.
        // This was all a lot tricker than you might expect (yes basic arithmetic).

        let truncate: Int

        if (self._shiftX > 0) {
            if (viewCellX == 0) {
                truncate = self._cellSize - self._shiftX
            }
            else if (viewCellX == self._viewCellEndX + self._viewColumnsExtra) {
                if (self._viewWidthExtra > 0) {
                    truncate = -((self._cellSize - self._shiftX + self._viewWidthExtra) % self._cellSize)
                }
                else {
                    truncate = -(self._cellSize - self._shiftX)
                }
            }
            else {
                truncate = 0
            }
        }
        else if (self._shiftX < 0) {
            if (viewCellX == 0) {
                truncate = -self._shiftX
            }
            else if (viewCellX == self._viewCellEndX + self._viewColumnsExtra) {
                if (self._viewWidthExtra > 0) {
                    truncate = -((self._viewWidthExtra - self._shiftX) % self._cellSize)
                }
                else {
                    truncate = self._shiftX
                }
            }
            else {
                truncate = 0
            }
        }
        else if ((self._viewWidthExtra > 0) && (viewCellX == self._viewCellEndX + self._viewColumnsExtra)) {
            truncate = -self._viewWidthExtra
        }
        else {
            truncate = 0
        }

        // Map the grid-view location to the cell-grid location.

        let gridCellX: Int = viewCellX - self._shiftCellX - ((self._shiftX > 0) ? 1 : 0)
        let gridCellY: Int = viewCellY - self._shiftCellY - ((self._shiftY > 0) ? 1 : 0)
        let foreground: CellColor = self.gridCell(gridCellX, gridCellY)?.foreground ?? self._viewBackground
        let foregroundOnly: Bool = false

        // Setup the offset for the buffer blocks; offset used within writeCellBlock.

        let shiftX: Int = (self._shiftX > 0) ? self._shiftX - self._cellSize : self._shiftX
        let shiftY: Int = (self._shiftY > 0) ? self._shiftY - self._cellSize : self._shiftY
        let offset: Int = ((self._cellSize * viewCellX) + shiftX +
                           (self._cellSizeTimesViewWidth * viewCellY + shiftY * self._viewWidth)) * Screen.depth
        let size: Int = self._buffer.count

        // Precompute as much as possible the specific color values needed in writeCellBlock;
        // the writeCellBlock function is real tight inner loop code so squeezing out optimizations.

        let fg: UInt32 = foreground.value
        let fgr: Float = Float(foreground.red)
        let fgg: Float = Float(foreground.green)
        let fgb: Float = Float(foreground.blue)
        let fga: UInt32 = UInt32(foreground.alpha) << CellColor.ASHIFT

        let bg: UInt32 = self._viewBackground.value
        let bgr: Float = Float(self._viewBackground.red)
        let bgg: Float = Float(self._viewBackground.green)
        let bgb: Float = Float(self._viewBackground.blue)

        // Loop through the blocks for the cell and write each of the indices to the buffer with the right colors/blends.
        // Being careful to truncate the left or right side of the cell appropriately (tricky stuff).

        self._buffer.withUnsafeMutableBytes { raw in

            guard let buffer: UnsafeMutableRawPointer = raw.baseAddress else { return }

            func writeCellBlock(_ block: BufferBlocks.BufferBlock, _ index: Int, _ count: Int)
            {
                // Uses/captures from outer scope: buffer; offset; fg, bg, and related values.

                let start: Int = offset + index

                guard start >= 0, (start + (count * Memory.bufferBlockSize)) < size else {
                    //
                    // N.B. Recently change about guard from "<= size" to  "< size" because it was off by one,
                    // just making a not of it here in case something for some reasone breaks (2025-05-15 12:40).
                    //
                    // At least (and only pretty sure) for the Y (vertical) case we get here on shifting;
                    // why; because we are being sloppy with the vertical, because it was easier.
                    //
                    // TODO but probably not because these micro optimizations are getting ridiculous:
                    // could precompute the block background times blend values based on the current
                    // view background (which in practice should rarely if ever change), would save
                    // subtraction of blend from 1.0 and its multiplication by background in this
                    // loop; if background did change would need to invalidate the blocks.
                    //
                    return
                }
                if (block.foreground) {
                    if (block.blend != 1.0) {
                        let blend: Float = block.blend
                        let blendr: Float = 1.0 - blend
                        Memory.fastcopy(to: buffer.advanced(by: start), count: count,
                                        value: (UInt32(UInt8(fgr * blend + bgr * blendr)) << CellColor.RSHIFT) |
                                               (UInt32(UInt8(fgg * blend + bgg * blendr)) << CellColor.GSHIFT) |
                                               (UInt32(UInt8(fgb * blend + bgb * blendr)) << CellColor.BSHIFT) | fga)
                    }
                    else {
                        Memory.fastcopy(to: buffer.advanced(by: start), count: count, value: fg)
                    }
                }
                else if (!foregroundOnly) {
                    Memory.fastcopy(to: buffer.advanced(by: start), count: count, value: bg)
                }
            }

            if (truncate != 0) {
                for block in self._bufferBlocks.blocks {
                    block.writeTruncated(shiftx: truncate, write: writeCellBlock)
                }
            }
            else {
                for block in self._bufferBlocks.blocks {
                    writeCellBlock(block, block.index, block.count)
                }
            }
        }
    }

    public var shiftedBy: CellLocation {
        return CellLocation(self.unscaled(self._shiftCellX * self._cellSize + self._shiftX),
                            self.unscaled(self._shiftCellY * self._cellSize + self._shiftY))
    }

    public func resizeCells(cellSizeIncrement: Int) {
        print("RESIZE: \(cellSizeIncrement)")
        let currentShift: CellLocation = self.shiftedBy
        self.configure(cellSize: self.unscaled(self._cellSize) + cellSizeIncrement,
                       cellPadding: self.unscaled(self._cellPadding),
                       cellShape: self._cellShape,
                       viewWidth: self.unscaled(self._viewWidth),
                       viewHeight: self.unscaled(self._viewHeight),
                       viewBackground: self._viewBackground,
                       viewTransparency: self._viewTransparency,
                       viewScaling: self._viewScaling)
        self.shift(shiftx: currentShift.x, shifty: currentShift.y)
    }

    public func update() {
        let currentShift: CellLocation = self.shiftedBy
        self.shift(shiftx: currentShift.x, shifty: currentShift.y)
    }

    public var cellSize: Int {
        self.unscaled(self._cellSize)
    }

    public var gridColumns: Int {
        self._gridColumns
    }

    public var gridRows: Int {
        self._gridRows
    }

    public var gridCells: [Cell] {
        self._gridCells
    }

    // Returns the cell-grid cell object for the given grid-view input location, or nil;
    // note that the display input location is always in unscaled units.
    //
    public func gridCell<T: Cell>(_ viewPoint: CGPoint) -> T? {
        if let gridPoint: CellLocation = self.gridCellLocation(viewPoint) {
            return self.gridCell(gridPoint.x, gridPoint.y)
        }
        return nil
    }

    // Returns the cell-grid cell object for the given cell-grid cell location, or nil.
    //
    public func gridCell<T: Cell>(_ gridCellX: Int, _ gridCellY: Int) -> T? {
        guard gridCellX >= 0, gridCellX < self._gridColumns, gridCellY >= 0, gridCellY < self._gridRows else {
            return nil
        }
        return self._gridCells[gridCellY * self._gridColumns + gridCellX] as? T
    }

    // Returns the cell-grid cell location of the given grid-view input point, or nil;
    // note that the display input location is always in unscaled units.
    //
    public func gridCellLocation(_ viewPoint: CGPoint) -> CellLocation? {
        return self.gridCellLocation(viewPoint.x, viewPoint.y)
    }

    public func gridCellLocation(_ viewPointX: CGFloat, _ viewPointY: CGFloat) -> CellLocation? {

        if let viewCellLocation: CellLocation = self.viewCellLocation(viewPointX, viewPointY) {
            let shiftX: Int = self.unscaled(self._shiftX)
            let shiftY: Int = self.unscaled(self._shiftY)
            let gridCellX: Int = viewCellLocation.x - self._shiftCellX - ((shiftX > 0) ? 1 : 0)
            guard gridCellX >= 0, gridCellX < self._gridColumns else { return nil }
            let gridCellY: Int = viewCellLocation.y - self._shiftCellY - ((shiftY > 0) ? 1 : 0)
            guard gridCellY >= 0, gridCellY < self._gridRows else { return nil }
            return CellLocation(gridCellX, gridCellY)
        }
        return nil
    }

    public func viewCellFromGridCellLocation(_ gridCellX: Int, _ gridCellY: Int) -> CellLocation? {
        let shiftX: Int = self.unscaled(self._shiftX)
        let shiftY: Int = self.unscaled(self._shiftY)
        let viewCellX: Int = gridCellX + self._shiftCellX + ((shiftX > 0) ? 1 : 0)
        let viewCellY: Int = gridCellY + self._shiftCellY + ((shiftY > 0) ? 1 : 0)
        return CellLocation(viewCellX, viewCellY)
    }

    // Returns the cell location relative to the grid-view of the given grid-view input point, or nil.
    //
    public func viewCellLocation(_ viewPoint: CGPoint) -> CellLocation? {
        return self.viewCellLocation(viewPoint.x, viewPoint.y)
    }

    public func viewCellLocation(_ viewPointX: CGFloat, _ viewPointY: CGFloat) -> CellLocation? {
        guard viewPointX >= 0.0, viewPointX < CGFloat(self._viewWidth),
              viewPointY >= 0.0, viewPointY < CGFloat(self._viewHeight) else { return nil }
        let shiftX: Int = self.unscaled(self._shiftX)
        let shiftY: Int = self.unscaled(self._shiftY)
        let cellSizeUnscaled: Int = self.unscaled(self._cellSize)
        let viewCellX: Int = ((shiftX > 0) ? (Int(floor(viewPointX)) + (cellSizeUnscaled - shiftX))
                                           : (Int(floor(viewPointX)) - shiftX)) / cellSizeUnscaled
        let viewCellY: Int = ((shiftY > 0) ? (Int(floor(viewPointY)) + (self.unscaled(self._cellSize) - shiftY))
                                           : (Int(floor(viewPointY)) - shiftY)) / cellSizeUnscaled
        return CellLocation(viewCellX, viewCellY)
    }

    // Normalizes an input point taking into account orientation et cetera.
    //
    public func normalizedPoint(screenPoint: CGPoint,
                                viewOrigin viewOrigin: CGPoint,
                                orientation: OrientationObserver) -> CGPoint
    {
        // Various oddities with upside-down mode and having to know the
        // previous orientation and whether or not we are an iPad and whatnot.
        //
        let x, y: CGFloat
        switch orientation.current {
        case .portrait:
            x = screenPoint.x - viewOrigin.x
            y = screenPoint.y - viewOrigin.y
        case .portraitUpsideDown:
            if (orientation.ipad) {
                x = CGFloat(self.unscaled(self._viewWidth)) - 1 - (screenPoint.x - viewOrigin.x)
                y = CGFloat(self.unscaled(self._viewHeight)) - 1 - (screenPoint.y - viewOrigin.y)
            }
            else if (orientation.previous.isLandscape) {
                x = screenPoint.y - viewOrigin.x
                y = CGFloat(self.unscaled(self._viewHeight)) - 1 - (screenPoint.x - viewOrigin.y)
            }
            else {
                x = screenPoint.x - viewOrigin.x
                y = screenPoint.y - viewOrigin.y
            }
        case .landscapeRight:
            x = screenPoint.y - viewOrigin.x
            y = CGFloat(self.unscaled(self._viewHeight)) - 1 - (screenPoint.x - viewOrigin.y)
        case .landscapeLeft:
            x = CGFloat(self.unscaled(self._viewWidth)) - 1 - (screenPoint.y - viewOrigin.x)
            y = screenPoint.x - viewOrigin.y
        default:
            x = screenPoint.x - viewOrigin.x
            y = screenPoint.y - viewOrigin.y
        }
        return CGPoint(x: x, y: y)
    }

    public var image: CGImage? {
        var image: CGImage?
        self._buffer.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { fatalError("No buffer base address") }
            if let context: CGContext = CGContext(
                data: baseAddress,
                width: self._viewWidth,
                height: self._viewHeight,
                bitsPerComponent: 8,
                bytesPerRow: self._viewWidth * Screen.depth,
                space: CellGrid.Defaults.colorSpace,
                bitmapInfo: CellGrid.Defaults.bitmapInfo
            ) {
                print("MAKE-IMAGE")
                image = context.makeImage()
            }
        }
        return image
    }

    public var imageScale: CGFloat {
        self.viewScale
    }

    private class BufferBlocks
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

    typealias PreferredSize = (cellSize: Int, viewWidth: Int, viewHeight: Int)

    // Returns a list of preferred sizes for the cell size, such that they fit evenly without bleeding
    // out past the end of the view; the given and returned dimensions are assumed to be unscaled values.
    //
    public static func preferredSize(viewWidth: Int, viewHeight: Int, cellSize: Int,
                                     preferredSizeMarginMax: Int = Defaults.preferredSizeMarginMax,
                                     enabled: Bool = true) -> PreferredSize
    {
        if (enabled) {
            let sizes = CellGridView.preferredSizes(viewWidth: viewWidth, viewHeight: viewHeight,
                                                    preferredSizeMarginMax: preferredSizeMarginMax)
            if let size = CellGridView.closestPreferredCellSize(in: sizes, to: cellSize) {
                return size
            }
        }
        return (viewWidth: viewWidth, viewHeight: viewHeight, cellSize: cellSize)
    }

    public static func preferredSizes(viewWidth: Int, viewHeight: Int,
                                      preferredSizeMarginMax: Int = Defaults.preferredSizeMarginMax)
                                      -> [PreferredSize] {
        let mindim: Int = min(viewWidth, viewHeight)
        guard mindim > 0 else { return [] }
        var results: [PreferredSize] = []
        for cellSize in 1...mindim {
            let ncols: Int = viewWidth / cellSize
            let nrows: Int = viewHeight / cellSize
            let usedw: Int = ncols * cellSize
            let usedh: Int = nrows * cellSize
            let leftx: Int = viewWidth - usedw
            let lefty: Int = viewHeight - usedh
            if ((leftx <= preferredSizeMarginMax) && (lefty <= preferredSizeMarginMax)) {
                results.append((cellSize: cellSize, viewWidth: usedw, viewHeight: usedh))
            }
        }
        return results
    }

    public static func closestPreferredCellSize(in list: [PreferredSize], to target: Int) -> PreferredSize? {
        return list.min(by: {
            let a: Int = abs($0.cellSize - target)
            let b: Int = abs($1.cellSize - target)
            return (a, $0.cellSize) < (b, $1.cellSize)
        })
    }

/*
    func printSizes(viewWidthInit: Int = 0, viewHeightInit: Int = 0, cellSizeInit: Int = 0, cellFitInit: Bool = false) {
        print("SCREEN>                   \(self.scaled(Screen.shared.width)) x \(self.scaled(Screen.shared.height))" +
              (self._viewScaling ? " (unscaled: \(Screen.shared.width) x \(Screen.shared.height))" : "") +
              " | SCALE: \(Screen.shared.scale()) | SCALING: \(self._viewScaling)")
        if ((viewWidthInit > 0) && (viewHeightInit > 0)) {
            print("VIEW-SIZE-INITIAL>        \(viewWidthInit) x \(viewHeightInit)" + (self._viewScaling ? " (unscaled)" : "") +
                  ((viewWidthInit != self.unscaled(self._viewWidth) ||
                   viewHeightInit != self.unscaled(self._viewHeight)
                   ? " -> PREFERRED: \(self.unscaled(self._viewWidth))" +
                     (" x \(self.unscaled(self._viewHeight))" + (self._viewScaling ? " (unscaled)" : "")) : "")))
        }
        if (cellSizeInit > 0) {
            print("CELL-SIZE-INITIAL>        \(cellSizeInit)" + (self._viewScaling ? " (unscaled)" : "") +
                   (cellSizeInit != self.unscaled(self._cellSize)
                    ? (" -> PREFERRED: \(self.unscaled(self._cellSize))" + (self._viewScaling ? " (unscaled)" : "")) : ""))
        }
        print("VIEW-SIZE>                \(self._viewWidth) x \(self._viewHeight)" +
              (self._viewScaling ?
               " (unscaled: \(self.unscaled(self._viewWidth)) x \(self.unscaled(self._viewHeight)))" : ""))
        print("CELL-SIZE>                \(self._cellSize)" +
              (self._viewScaling ? " (unscaled: \(self.unscaled(self._cellSize)))" : ""))
        print("CELL-PADDING>             \(self._cellPadding)" +
              (self._viewScaling ? " (unscaled: \(self.unscaled(self._cellPadding)))" : ""))
        print("PREFERRED-SIZING>         \(cellFitInit)")
        if (cellFitInit) {
            let sizes = CellGridView.preferredSizes(viewWidth: self.unscaled(self._viewWidth),
                                                    viewHeight: self.unscaled(self._viewHeight))
            for size in sizes {
                print("PREFFERED>" +
                      " CELL-SIZE \(String(format: "%3d", self.scaled(size.cellSize)))" +
                      (self._viewScaling ? " (unscaled: \(String(format: "%3d", size.cellSize)))" : "") +
                      " VIEW-SIZE: \(String(format: "%3d", self.scaled(size.viewWidth)))" +
                      " x \(String(format: "%3d", self.scaled(size.viewHeight)))" +
                      (self._viewScaling ?
                       " (unscaled: \(String(format: "%3d", size.viewWidth))" +
                       " x \(String(format: "%3d", size.viewHeight)))" : "") +
                      " MARGINS: \(String(format: "%2d", self._viewWidth - self.scaled(size.viewWidth)))" +
                      " x \(String(format: "%2d", self._viewHeight - self.scaled(size.viewHeight)))" +
                      (self._viewScaling ? (" (unscaled: \(String(format: "%2d", self.unscaled(self._viewWidth) - size.viewWidth))"
                                               + " x \(String(format: "%2d", self.unscaled(self._viewHeight) - size.viewHeight)))") : "") +
                      ((size.cellSize == self.unscaled(self._cellSize)) ? " <<<" : ""))
            }
        }
    }
*/
}
