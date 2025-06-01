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
// and "grid-view" to mean the viewable window (image) in which is displayed a subset of the cell-grid.
// We say "point" or "view-point" to mean a pixel coordinate (coming from a gesture) which is not scaled.
// We say "location" or "cell-location" to mean a cell-based coordinate on the cell-grid or grid-view.

@MainActor
class CellGridView
{
    struct Defaults {
        // 
        // The size related properties here (being effectively outward facing) are unscaled.
        //
        public static var cellPaddingMax: Int = 8
        public static var cellSizeMax: Int = 200
        public static var cellSizeInnerMin: Int = 3
        public static var preferredSizeMarginMax: Int = 30
        public static let cellAntialiasFade: Float = 0.6  // smaller is smoother
        public static let cellRoundedRectangleRadius: Float = 0.25
    }

    // Note that internally all size related properties are stored as scaled;
    // but that all outward facing references to such properties and unscaled,
    // unless otherwise specifed in the property name, e.g. cellSizeScaled.

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
    private var _cellShape: CellShape = CellShape.rounded

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

    // We store unscaled versions of commonly used properties.
    //
    private var _unscaled_viewWidth: Int = 0
    private var _unscaled_viewHeight: Int = 0
    private var _unscaled_cellSize: Int = 0
    private var _unscaled_cellPadding: Int = 0
    private var _unscaled_shiftCellX: Int = 0
    private var _unscaled_shiftCellY: Int = 0
    private var _unscaled_shiftX: Int = 0
    private var _unscaled_shiftY: Int = 0

    private  var _bufferBlocks: CellGridView.BufferBlocks = BufferBlocks(width: 0)
    //
    // The only reason this _buffer is internal and not private is that we factored
    // out the image property into CellGridView+Image.swift which needs it.
    //
    internal var _buffer: [UInt8] = []

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
         gridCellFactory: Cell.Factory? = nil)
    {
        let preferredSize = CellGridView.preferredSize(viewWidth: viewWidth, viewHeight: viewHeight,
                                                       cellSize: cellSize, enabled: cellFit)
        self.configure(cellSize: preferredSize.cellSize,
                       cellPadding: cellPadding,
                       cellShape: cellShape,
                       viewWidth: preferredSize.viewWidth,
                       viewHeight: preferredSize.viewHeight,
                       viewBackground: viewBackground,
                       viewTransparency: viewTransparency,
                       viewScaling: viewScaling)

        self._gridColumns = gridColumns > 0 ? gridColumns : self._viewColumns
        self._gridRows = gridRows > 0 ? gridRows : self._viewRows
        self._gridCellEndX = self._gridColumns - 1
        self._gridCellEndY = self._gridRows - 1
        self._gridCellFactory = gridCellFactory
        self._gridCells = self.defineGridCells(gridColumns: self._gridColumns,
                                               gridRows: self._gridRows,
                                               gridCellFactory: self._gridCellFactory,
                                               foreground: CellGrid.Defaults.cellForeground)

        #if targetEnvironment(simulator)
            self.printSizes(viewWidthInit: viewWidth, viewHeightInit: viewHeight,
                            cellSizeInit: cellSize, cellFitInit: cellFit)
        #endif

        if (DefaultSettings.centerCellGrid) {
            self.center()
        }
        else {
            self.shift(shiftx: 0, shifty: 0, scaled: false)
        }
    }

    internal func configure(cellSize: Int,
                            cellPadding: Int,
                            cellShape: CellShape,
                            viewWidth: Int,
                            viewHeight: Int,
                            viewBackground: CellColor,
                            viewTransparency: UInt8,
                            viewScaling: Bool,
                            scaled: Bool = false)
    {
        // N.B. This here first so subsequent calls to self.scaled work properly.

        self._viewScaling = [CellShape.square, CellShape.inset].contains(cellShape) ? false : viewScaling

        // Convert to scaled and sanity (max/min) check the cell-size and cell-padding.

        let cellPadding: Int = constrainCellPadding(!scaled ? self.scaled(cellPadding) : cellPadding, scaled: true)
        let cellSize: Int = constrainCellSize(!scaled ? self.scaled(cellSize) : cellSize, cellPadding: cellPadding, scaled: true)
        let viewWidth: Int = !scaled ? self.scaled(viewWidth) : viewWidth
        let viewHeight: Int = !scaled ? self.scaled(viewHeight) : viewHeight

        self._viewWidth = viewWidth
        self._viewHeight = viewHeight
        self._cellSize = cellSize
        self._cellSizeTimesViewWidth = self._cellSize * self._viewWidth
        self._cellPadding = cellPadding
        self._cellShape = cellShape

        self._unscaled_viewWidth = self.unscaled(viewWidth)
        self._unscaled_viewHeight = self.unscaled(viewHeight)
        self._unscaled_cellSize = self.unscaled(cellSize)
        self._unscaled_cellPadding = self.unscaled(cellPadding)

        // Note that viewColumns/Rows is the number of cells the
        // view CAN (possibly) FULLY display horizontally/vertically.

        self._viewWidthExtra = self._viewWidth % self._cellSize
        self._viewHeightExtra = self._viewHeight % self._cellSize
        self._viewColumns = self._viewWidth / self._cellSize
        self._viewRows = self._viewHeight / self._cellSize
        self._viewColumnsExtra = (self._viewWidthExtra > 0) ? 1 : 0
        self._viewRowsExtra = (self._viewHeightExtra > 0) ? 1 : 0
        self._viewCellEndX = self._viewColumns + self._viewColumnsExtra - 1
        self._viewCellEndY = self._viewRows + self._viewRowsExtra - 1
        self._viewBackground = viewBackground
        self._viewTransparency = viewTransparency

        self._buffer = Memory.allocate(self._viewWidth * self._viewHeight * Screen.depth)
        self._bufferBlocks = BufferBlocks.createBufferBlocks(bufferSize: self._buffer.count,
                                                             viewWidth: self._viewWidth,
                                                             viewHeight: self._viewHeight,
                                                             cellSize: self._cellSize,
                                                             cellPadding: self._cellPadding,
                                                             cellShape: self._cellShape,
                                                             cellTransparency: self._viewTransparency)
    }

    internal func constrainCellSize(_ cellSize: Int, cellPadding: Int? = nil, scaled: Bool = false) -> Int {
        let cellSizeInnerMin: Int = self.scaled(Defaults.cellSizeInnerMin)
        let cellSizeMax: Int = self.scaled(Defaults.cellSizeMax)
        let cellPadding: Int = !scaled ? self.scaled(cellPadding ?? self.cellPadding) : (cellPadding ?? self.cellPaddingScaled)
        return cellSize.clamped(cellSizeInnerMin + (cellPadding * 2)...cellSizeMax)
    }

    private func constrainCellPadding(_ cellPadding: Int, scaled: Bool = false) -> Int {
        let cellPaddingMax: Int = self.scaled(Defaults.cellPaddingMax)
        let cellPadding: Int = !scaled ? self.scaled(cellPadding) : cellPadding
        return cellPadding.clamped(0...cellPaddingMax)
    }

    public var viewScaling: Bool {
        get { self._viewScaling }
        set {
            if (newValue) {
                if (!self._viewScaling) {
                    self.scale()
                }
            }
            else if (self._viewScaling) {
                self.unscale()
            }
        }
    }

    public var viewScale: CGFloat {
        Screen.shared.scale(scaling: self._viewScaling)
    }

    internal func scaled(_ value: Int) -> Int {
        return Screen.shared.scaled(value, scaling: self._viewScaling)
    }

    internal func scaled(_ value: Int, force: Bool) -> Int {
        return Screen.shared.scaled(value, scaling: force ? true : self._viewScaling)
    }

    internal func unscaled(_ value: Int) -> Int {
        return Screen.shared.unscaled(value, scaling: self._viewScaling)
    }

    internal func unscaled(_ value: Int, force: Bool) -> Int {
        return Screen.shared.unscaled(value, scaling: force ? true : self._viewScaling)
    }

    public   var viewWidth: Int            { self._unscaled_viewWidth }
    public   var viewHeight: Int           { self._unscaled_viewHeight }
    public   var viewColumns: Int          { self._viewColumns }
    public   var viewRows: Int             { self._viewRows }
    public   var viewBackground: CellColor { self._viewBackground }
    public   var viewTransparency: UInt8   { self._viewTransparency }
    public   var cellSize: Int             { self._unscaled_cellSize }
    public   var cellPadding: Int          { self._unscaled_cellPadding }
    public   var cellShape: CellShape      { self._cellShape }
    public   var gridColumns: Int          { self._gridColumns }
    public   var gridRows: Int             { self._gridRows }
    public   var gridCells: [Cell]         { self._gridCells }

    internal var shiftCellX: Int  { self._unscaled_shiftCellX }
    internal var shiftCellY: Int  { self._unscaled_shiftCellY }
    internal var shiftX: Int      { self._unscaled_shiftX }
    internal var shiftY: Int      { self._unscaled_shiftY }
    internal var shiftTotalX: Int { self._unscaled_shiftX + (self._unscaled_shiftCellX * self._unscaled_cellSize) }
    internal var shiftTotalY: Int { self._unscaled_shiftY + (self._unscaled_shiftCellY * self._unscaled_cellSize) }

    internal var viewWidthScaled: Int   { self._viewWidth }
    internal var viewHeightScaled: Int  { self._viewHeight }
    internal var viewCellEndX: Int      { self._viewCellEndX }
    internal var viewCellEndY: Int      { self._viewCellEndY }
    internal var cellSizeScaled: Int    { self._cellSize }
    internal var cellPaddingScaled: Int { self._cellPadding }
    internal var shiftCellScaledX: Int  { self._shiftCellX }
    internal var shiftCellScaledY: Int  { self._shiftCellY }
    internal var shiftScaledX: Int      { self._shiftX }
    internal var shiftScaledY: Int      { self._shiftY }
    internal var shiftTotalScaledX: Int { self._shiftX + (self._shiftCellX * self._cellSize) }
    internal var shiftTotalScaledY: Int { self._shiftY + (self._shiftCellY * self._cellSize) }

    // Sets the cell-grid within the grid-view to be shifted by the given amount,
    // from the upper-left; note that the given shiftx and shifty values are unscaled.
    //
    public func shift(shiftx: Int, shifty: Int, dragging: Bool = false, scaled: Bool = false)
    {
        #if targetEnvironment(simulator)
            let debugStart = Date()
        #endif

        // If the given scaled argument is false then the passed shiftx/shifty arguments are
        // assumed to be unscaled and so we scale them; as this function operates on scaled values.

        var shiftX: Int = !scaled ? self.scaled(shiftx) : shiftx, shiftCellX: Int
        var shiftY: Int = !scaled ? self.scaled(shifty) : shifty, shiftCellY: Int

        // Normalize the given pixel level shift to cell and pixel level.

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
        // - restrictShiftStrict
        //   Disallow the left-most cell of the cell-grid being right-shifted past the left-most
        //   position of the grid-view, and the right-most cell of the cell-grid being left-shifted
        //   past the right-most position of the grid-view; similarly for the vertical.
        //
        // - restrictShiftLenient
        //   Disallow the left-most cell of the cell-grid being right-shifted past the right-most
        //   position of the grid-view, and the right-most cell of the grid-view being left-shifted
        //   past the left-most position of the grid-view; similarly for the vertical.

        func restrictShiftStrict(shiftCell: inout Int, shift: inout Int,
                                 cellSize: Int,
                                 viewSize: Int,
                                 viewSizeExtra _: Int,
                                 viewCellEnd _: Int,
                                 gridCells: Int,
                                 gridCellEnd _: Int,
                                 dragging: Bool = false) {
            var totalShift = (shiftCell * cellSize) + shift
            let gridSize: Int = gridCells * cellSize
            if (gridSize < viewSize) {
                //
                // The entire cell-grid being smaller than the grid-view requires
                // slightly difference logic than the presumably more commmon case.
                //
                if ((shift < 0) || (shiftCell < 0)) {
                    shiftCell = 0
                    shift = 0
                }
                else if (totalShift > (viewSize - gridSize)) {
                    totalShift = (viewSize - gridSize)
                    shiftCell = totalShift / cellSize
                    shift = totalShift % cellSize
                }
            }
            else if (!dragging) {
                let draggingShiftMax: Int = dragging ? Int(round(Double(cellSize) / 2.0)) : 0
                if ((shift > 0) || (shiftCell > 0)) {
                    shift = 0
                    shiftCell = 0
                }
                else if ((shift < 0) || (shiftCell < 0)) {
                    if ((totalShift < 0) && ((gridSize + totalShift) < viewSize)) {
                        totalShift = viewSize - gridSize
                        shiftCell = totalShift / cellSize
                        shift = totalShift % cellSize
                    }
                }
            }
        }

        func restrictShiftLenient(shiftCellXY: inout Int, shiftXY: inout Int,
                                  viewCellEndXY: Int,
                                  viewSizeExtra: Int,
                                  viewSize: Int,
                                  gridCellEndXY: Int) {
            if (shiftCellXY >= viewCellEndXY) {
                if (viewSizeExtra > 0) {
                    let totalShift = (shiftCellXY * self._cellSize) + shiftXY
                    if ((viewSize - totalShift) <= self._cellSize) {
                        let viewSizeAdjusted = viewSize - self._cellSize
                        shiftCellXY = viewSizeAdjusted / self._cellSize
                        shiftXY = viewSizeAdjusted % self._cellSize
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

        if (DefaultSettings.restrictShiftStrict) {
            restrictShiftStrict(shiftCell: &shiftCellX, shift: &shiftX,
                                cellSize: self._cellSize,
                                viewSize: self._viewWidth,
                                viewSizeExtra: self._viewWidthExtra,
                                viewCellEnd: self._viewCellEndX - self._viewColumnsExtra,
                                gridCells: self._gridColumns,
                                gridCellEnd: self._gridCellEndX,
                                dragging: dragging)
            restrictShiftStrict(shiftCell: &shiftCellY, shift: &shiftY,
                                cellSize: self._cellSize,
                                viewSize: self._viewHeight,
                                viewSizeExtra: self._viewHeightExtra,
                                viewCellEnd: self._viewCellEndY - self._viewRowsExtra,
                                gridCells: self._gridRows,
                                gridCellEnd: self._gridCellEndY,
                                dragging: dragging)
        }
        else {
            restrictShiftLenient(shiftCellXY: &shiftCellX,
                                 shiftXY: &shiftX,
                                 viewCellEndXY: self._viewCellEndX - self._viewColumnsExtra,
                                 viewSizeExtra: self._viewWidthExtra,
                                 viewSize: self._viewWidth,
                                 gridCellEndXY: self._gridCellEndX)
            restrictShiftLenient(shiftCellXY: &shiftCellY,
                                 shiftXY: &shiftY,
                                 viewCellEndXY: self._viewCellEndY - self._viewRowsExtra,
                                 viewSizeExtra: self._viewHeightExtra,
                                 viewSize: self._viewHeight,
                                 gridCellEndXY: self._gridCellEndY)
        }

        // Update the shift related values for the view.

        self._shiftCellX = shiftCellX
        self._shiftCellY = shiftCellY
        self._shiftX = shiftX
        self._shiftY = shiftY
        let unscaled_shiftTotalX: Int = self.unscaled(self._shiftX + (self._shiftCellX * self._cellSize))
        let unscaled_shiftTotalY: Int = self.unscaled(self._shiftY + (self._shiftCellY * self._cellSize))
        self._unscaled_shiftCellX = unscaled_shiftTotalX / self._unscaled_cellSize
        self._unscaled_shiftX = unscaled_shiftTotalX % self._unscaled_cellSize
        self._unscaled_shiftCellY = unscaled_shiftTotalY / self._unscaled_cellSize
        self._unscaled_shiftY = unscaled_shiftTotalY % self._unscaled_cellSize

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
        self._viewCellEndX = self._viewColumns + self._viewColumnsExtra - 1

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
        self._viewCellEndY = self._viewRows + self._viewRowsExtra - 1

        // Now actually write the cells to the view.

        for vy in 0...self._viewCellEndY {
            for vx in 0...self._viewCellEndX {
                self.writeCell(viewCellX: vx, viewCellY: vy)
            }
        }

        #if targetEnvironment(simulator)
            let shiftScaledXR: Int = modulo(self._cellSize + self._shiftX - self._viewWidthExtra, self._cellSize)
            var even: Bool = false
            if [0, 1].contains(abs(abs(shiftScaledXR) - abs(self.shiftScaledX))) {
                even = true
            }
            else if ((self.shiftScaledX == -(self.cellSizeScaled - 1)) && (shiftScaledXR == 0)) {
                even = true
            }
            else if (self.shiftScaledX > 0) {
                if [0, 1].contains(abs(self.shiftScaledX - (self.cellSizeScaled - shiftScaledXR))) {
                    even = true
                }
            }
            print(String(format: "SHIFT(\(shiftx),\(shifty)) %.5f" +
                                 (self._viewScaling ? " SC" : " US") +
                              // " VW:\(self._viewWidth)" +
                              // " VWE:\(self._viewWidthExtra)" +
                              // " VC:\(self.viewColumns)" +
                              // " VCE:\(self._viewColumnsExtra)" +
                                 " CS:\(self.cellSizeScaled)" +
                                 " CSU:\(self.cellSize)" +
                                 " SHT:\(self.shiftTotalScaledX),\(self.shiftTotalScaledY)" +
                                 " SHTU:\(self.shiftTotalX),\(self.shiftTotalY)" +
                                 " SHC:\(self.shiftCellScaledX),\(shiftCellScaledY)" +
                                 " SHCU:\(self.shiftCellX),\(shiftCellY)" +
                                 " SH:\(self.shiftScaledX),\(shiftScaledY)" +
                                 " SHU:\(self.shiftX),\(self.shiftY)" +
                                 " SHO:\(shiftScaledXR)" +
                                 (even ? " EVEN" : " UNEVEN"),
                  Date().timeIntervalSince(debugStart)))
        #endif
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
            else if (viewCellX == self._viewCellEndX) {
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
            else if (viewCellX == self._viewCellEndX) {
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
        else if ((self._viewWidthExtra > 0) && (viewCellX == self._viewCellEndX)) {
            truncate = -self._viewWidthExtra
        }
        else {
            truncate = 0
        }

        // Map the grid-view location to the cell-grid location.

        let gridCellX: Int = viewCellX - self._shiftCellX - ((self._shiftX > 0) ? 1 : 0)
        let gridCellY: Int = viewCellY - self._shiftCellY - ((self._shiftY > 0) ? 1 : 0)
        //
        // Another micro optimization could be if this view-cell does not correspond to a grid-cell
        // at all (i.e. the below gridCell call returns nil), i.e this is an empty space, then the
        // cell buffer block that we use can be a simplified one which just writes all background;
        // but this is probably not really a typical/common case for things we can think of for now.
        //
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
                    // N.B. Recently changed above guard from "<= size" to  "< size" because it was off by one,
                    // just making a note of it here in case something for some reasone breaks (2025-05-15 12:40).
                    //
                    // At least (and only pretty sure) for the Y (vertical) case we get here on shifting; why;
                    // because we are being sloppy with the vertical, because it was easier; think fine though.
                    //
                    // TODO: But probably not; because these micro optimizations are getting ridiculous:
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

    public func center()
    {
        let gridWidth: Int = self.gridColumns * self.cellSize
        let gridHeight: Int = self.gridRows * self.cellSize
        let shiftTotalX: Int = -Int(round(Double(gridWidth) / 2.0))
        let shiftTotalY: Int = -Int(round(Double(gridHeight) / 2.0))
        self.shift(shiftx: shiftTotalX, shifty: shiftTotalY)
    }

    public func scale() {
        guard !self._viewScaling else {
            return
        }
        let shiftTotalX: Int = self.scaled(self.shiftTotalX, force: true)
        let shiftTotalY: Int = self.scaled(self.shiftTotalY, force: true)
        self.configure(cellSize: self.cellSize,
                       cellPadding: self.cellPadding,
                       cellShape: self.cellShape,
                       viewWidth: self.viewWidth,
                       viewHeight: self.viewHeight,
                       viewBackground: self.viewBackground,
                       viewTransparency: self.viewTransparency,
                       viewScaling: true)
        self.shift(shiftx: shiftTotalX, shifty: shiftTotalY, scaled: true)
    }

    public func unscale() {
        guard self._viewScaling else {
            return
        }
        let shiftTotalX: Int = self.unscaled(self.shiftTotalScaledX, force: true)
        let shiftTotalY: Int = self.unscaled(self.shiftTotalScaledY, force: true)
        self.configure(cellSize: self.cellSize,
                       cellPadding: self.cellPadding,
                       cellShape: self.cellShape,
                       viewWidth: self.viewWidth,
                       viewHeight: self.viewHeight,
                       viewBackground: self.viewBackground,
                       viewTransparency: self.viewTransparency,
                       viewScaling: false)
        self.shift(shiftx: shiftTotalX, shifty: shiftTotalY, scaled: false)
    }
}
