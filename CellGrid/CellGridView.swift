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
class CellGridView
{
    struct Defaults {
        // 
        // The size related properties here (being effectively outward facing) are unscaled.
        //
        public static var cellPaddingMax: Int = 8
        public static var cellSizeMax: Int = 200
        public static var cellSizeInnerMin: Int = 6
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
    private var _viewColumnEndsVisible: Int = 0
    private var _viewRowEndsVisible: Int = 0
    private var _viewCellEndX: Int = 0
    private var _viewCellEndY: Int = 0
    private var _viewBackground: CellColor = CellColor.black
    private var _viewTransparency: UInt8 = 0
    private var _viewScaling: Bool = true

    internal var _viewColumnsDebugInitial: Int = 0
    internal var _viewRowsDebugInitial: Int = 0

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
        self._gridColumns = gridColumns > 0 ? gridColumns : self._viewColumns // TODO the else on this doesnt make sense (0)
        self._gridRows = gridRows > 0 ? gridRows : self._viewRows
        self._gridCellEndX = self._gridColumns - 1
        self._gridCellEndY = self._gridRows - 1
        self._gridCellFactory = gridCellFactory
        self._gridCells = self.defineGridCells(gridColumns: self._gridColumns,
                                               gridRows: self._gridRows,
                                               gridCellFactory: self._gridCellFactory,
                                               foreground: CellGrid.Defaults.cellForeground)

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

        #if targetEnvironment(simulator)
            self.printSizes(viewWidthInit: viewWidth, viewHeightInit: viewHeight,
                            cellSizeInit: cellSize, cellFitInit: cellFit)
        #endif
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
        // Sanity check the cell-size and cell-padding.

        var cellPadding: Int = cellPadding.clamped(0...Defaults.cellPaddingMax)
        var cellSize = cellSize.clamped(Defaults.cellSizeInnerMin + (cellPadding * 2)...Defaults.cellSizeMax)

        // N.B. It is important that this happens here first
        // so that subsequent calls to self.scaled work property.
        //
        self._viewScaling = [CellShape.square, CellShape.inset].contains(cellShape) ? false : viewScaling

        self._viewWidth = self.scaled(viewWidth)
        self._viewHeight = self.scaled(viewHeight)
        self._cellSize = self.scaled(cellSize)
        self._cellSizeTimesViewWidth = self._cellSize * self._viewWidth
        self._cellPadding = self.scaled(cellPadding)

        self._unscaled_viewWidth = viewWidth
        self._unscaled_viewHeight = viewHeight
        self._unscaled_cellSize = cellSize
        self._unscaled_cellPadding = cellPadding

        // Note that viewColumns/Rows is the number of cells the
        // view CAN (possibly) FULLY display horizontally/vertically.

        self._viewWidthExtra = self._viewWidth % self._cellSize
        self._viewHeightExtra = self._viewHeight % self._cellSize
        self._viewColumns = self._viewWidth / self._cellSize
        self._viewRows = self._viewHeight / self._cellSize
        self._viewColumnsExtra = (self._viewWidthExtra > 0) ? 1 : 0
        self._viewRowsExtra = (self._viewHeightExtra > 0) ? 1 : 0
        self._viewColumnEndsVisible = self._viewColumns
        self._viewRowEndsVisible = self._viewRows
        self._viewCellEndX = self._viewColumns + self._viewColumnsExtra - 1
        self._viewCellEndY = self._viewRows + self._viewRowsExtra - 1

        self._viewColumnsDebugInitial = self._viewColumns
        self._viewRowsDebugInitial = self._viewRows

        self._buffer = Memory.allocate(self._viewWidth * self._viewHeight * Screen.depth)
        self._bufferBlocks = BufferBlocks.createBufferBlocks(bufferSize: self._buffer.count,
                                                             viewWidth: self._viewWidth,
                                                             viewHeight: self._viewHeight,
                                                             cellSize: self._cellSize,
                                                             cellPadding: self._cellPadding,
                                                             cellShape: self._cellShape,
                                                             cellTransparency: self._viewTransparency)
        #if targetEnvironment(simulator)
            self.printSizes()
        #endif
    }

    private func configureScaled(cellSize: Int,
                                 cellPadding: Int,
                                 cellShape: CellShape,
                                 viewWidth: Int,
                                 viewHeight: Int,
                                 viewBackground: CellColor,
                                 viewTransparency: UInt8,
                                 viewScaling: Bool)
    {
        // Sanity check the cell-size and cell-padding.

        let cellPaddingMax: Int = self.scaled(Defaults.cellPaddingMax)
        let cellSizeInnerMin: Int = self.scaled(Defaults.cellSizeInnerMin)
        let cellSizeMax: Int = self.scaled(Defaults.cellSizeMax)
        var cellPadding: Int = cellPadding.clamped(0...cellPaddingMax)
        //
        // TODO
        // Not sure this is being imposed correctly ...
        // Think if we reach the max better make sure not to do anything else like shift etc; havent thought through ...
        //
        var cellSize = cellSize.clamped(cellSizeInnerMin + (cellPadding * 2)...cellSizeMax)

        // N.B. It is important that this happens here first
        // so that subsequent calls to self.scaled work property.
        //
        self._viewScaling = [CellShape.square, CellShape.inset].contains(cellShape) ? false : viewScaling

        self._viewWidth = viewWidth
        self._viewHeight = viewHeight
        self._cellSize = cellSize
        self._cellSizeTimesViewWidth = self._cellSize * self._viewWidth
        self._cellPadding = cellPadding

        self._unscaled_viewWidth = self.unscaled(viewWidth)
        self._unscaled_viewHeight = self.unscaled(viewHeight)
        self._unscaled_cellSize = self.unscaled(cellSize)
        self._unscaled_cellPadding = self.unscaled(cellPadding)

        self._viewWidthExtra = self._viewWidth % self._cellSize
        self._viewHeightExtra = self._viewHeight % self._cellSize
        self._viewColumns = self._viewWidth / self._cellSize
        self._viewRows = self._viewHeight / self._cellSize
        self._viewColumnsExtra = (self._viewWidthExtra > 0) ? 1 : 0
        self._viewRowsExtra = (self._viewHeightExtra > 0) ? 1 : 0
        self._viewColumnEndsVisible = self._viewColumns
        self._viewRowEndsVisible = self._viewRows
        self._viewCellEndX = self._viewColumns + self._viewColumnsExtra - 1
        self._viewCellEndY = self._viewRows + self._viewRowsExtra - 1

        self._buffer = Memory.allocate(self._viewWidth * self._viewHeight * Screen.depth)
        self._bufferBlocks = BufferBlocks.createBufferBlocks(bufferSize: self._buffer.count,
                                                             viewWidth: self._viewWidth,
                                                             viewHeight: self._viewHeight,
                                                             cellSize: self._cellSize,
                                                             cellPadding: self._cellPadding,
                                                             cellShape: self._cellShape,
                                                             cellTransparency: self._viewTransparency)
        #if targetEnvironment(simulator)
            self.printSizes()
        #endif
    }

    private func defineGridCells(gridColumns: Int, gridRows: Int,
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

    public var viewScaling: Bool {
        get { self._viewScaling }
        set {
            if (newValue != self._viewScaling) {
                let shiftedCurrent: CellLocation = self.shifted
                self.configure(cellSize: self.cellSize,
                               cellPadding: self.cellPadding,
                               cellShape: self.cellShape,
                               viewWidth: self.viewWidth,
                               viewHeight: self.viewHeight,
                               viewBackground: self.viewBackground,
                               viewTransparency: self.viewTransparency,
                               viewScaling: newValue)
                self.shift(shiftx: shiftedCurrent.x, shifty: shiftedCurrent.y)
            }
        }
    }

    public var viewScale: CGFloat {
        Screen.shared.scale(scaling: self._viewScaling)
    }

    internal func scaled(_ value: Int) -> Int {
        return Screen.shared.scaled(value, scaling: self._viewScaling)
    }

    internal func unscaled(_ value: Int) -> Int {
        return Screen.shared.unscaled(value, scaling: self._viewScaling)
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

    internal var shiftCellX: Int           { self._shiftCellX }
    internal var shiftCellY: Int           { self._shiftCellY }
    internal var shiftX: Int               { self._unscaled_shiftX }
    internal var shiftY: Int               { self._unscaled_shiftY }
    internal var shiftScaledX: Int         { self._shiftX }
    internal var shiftScaledY: Int         { self._shiftY }
    internal var shiftScaledXR: Int        { modulo(self._cellSize + self._shiftX - self._viewWidthExtra, self._cellSize) }
    internal var shiftScaledYB: Int        { modulo(self._cellSize + self._shiftY - self._viewHeightExtra, self._cellSize) }

    internal var viewWidthScaled: Int       { self._viewWidth }
    internal var viewHeightScaled: Int      { self._viewHeight }
    internal var viewColumnEndsVisible: Int { self._viewColumnEndsVisible }
    internal var viewRowEndsVisible: Int    { self._viewRowEndsVisible }
    internal var viewCellEndX: Int          { self._viewCellEndX }
    internal var viewCellEndY: Int          { self._viewCellEndY }
    internal var cellSizeScaled: Int        { self._cellSize }
    internal var cellPaddingScaled: Int     { self._cellPadding }

    internal var viewColumnsVisible: Int    { self._viewColumns + self._viewColumnsExtra }
    internal var viewRowsVisible: Int       { self._viewRows + self._viewRowsExtra }

    public var shifted: CellLocation {
        return CellLocation(self.shiftCellX * self.cellSize + self.shiftX,
                            self.shiftCellY * self.cellSize + self.shiftY)
    }

    public func shifted(scaled: Bool = false) -> CellLocation {
        return scaled ? CellLocation(self.shiftCellX * self.cellSizeScaled + self.shiftScaledX,
                                     self.shiftCellY * self.cellSizeScaled + self.shiftScaledY)
                      : CellLocation(self.shiftCellX * self.cellSize + self.shiftX,
                                     self.shiftCellY * self.cellSize + self.shiftY)
    }

    public func shift(shiftx: Int, shifty: Int) {
        self.shift(shiftx: shiftx, shifty: shifty, scaled: false)
    }

    // Sets the cell-grid within the grid-view to be shifted by the given amount,
    // from the upper-left; note that the given shiftx and shifty values are unscaled.
    //
    public func shift(shiftx: Int, shifty: Int, scaled: Bool)
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
                        let adjustedSize = viewSize - self._cellSize
                        shiftCellXY = adjustedSize / self._cellSize
                        shiftXY = adjustedSize % self._cellSize
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
                      viewCellEndXY: self._viewCellEndX - self._viewColumnsExtra,
                      viewSizeExtra: self._viewWidthExtra,
                      viewSize: self._viewWidth,
                      gridCellEndXY: self._gridCellEndX)
        restrictShift(shiftCellXY: &shiftCellY,
                      shiftXY: &shiftY,
                      viewCellEndXY: self._viewCellEndY - self._viewRowsExtra,
                      viewSizeExtra: self._viewHeightExtra,
                      viewSize: self._viewHeight,
                      gridCellEndXY: self._gridCellEndY)

        // Update the shift related values for the view.

        self._shiftCellX = shiftCellX
        self._shiftCellY = shiftCellY
        self._shiftX = shiftX
        self._shiftY = shiftY
        self._unscaled_shiftX = self.unscaled(shiftX)
        self._unscaled_shiftY = self.unscaled(shiftY)

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

        // Update the view{Column,Row}EndsVisible values; maybe this can
        // be unified with the view{Columns,Rows}Extra values; maybe not.
        //
        if (self._viewWidthExtra == 0) {
            self._viewColumnEndsVisible = self._viewColumns
        }
        else if (self._shiftX == 0) {
            self._viewColumnEndsVisible = self._viewColumns
        }
        else if (self._viewWidthExtra > (self._cellSize + self._shiftX)) {
            self._viewColumnEndsVisible = self._viewColumns + 1
        }
        else {
            self._viewColumnEndsVisible = self._viewColumns
        }
        if (self._viewHeightExtra == 0) {
            self._viewRowEndsVisible = self._viewRows
        }
        else if (self._shiftY == 0) {
            self._viewRowEndsVisible = self._viewRows
        }
        else if (self._viewHeightExtra > (self._cellSize + self._shiftY)) {
            self._viewRowEndsVisible = self._viewRows + 1
        }
        else {
            self._viewRowEndsVisible = self._viewRows
        }

        // Now actually write the cells to the view.

        for vy in 0...self._viewCellEndY {
            for vx in 0...self._viewCellEndX {
                self.writeCell(viewCellX: vx, viewCellY: vy)
            }
        }

        #if targetEnvironment(simulator)
            //let xyzzy = abs(abs(self.shiftScaledXR) - abs(self.shiftScaledX))
            // let okay =  (xyzzy == 1) || (xyzzy == 0)
            //// let okay =  (xyzzy == 1) || (xyzzy == 0) || ((self.shiftScaledX == -(self.cellSize - 1)) && (self.shiftScaledXR == 0))
            var okay: Bool = false
            if [0, 1].contains(abs(abs(self.shiftScaledXR) - abs(self.shiftScaledX))) {
                okay = true
            }
            else if ((self.shiftScaledX == -(self.cellSizeScaled - 1)) && (self.shiftScaledXR == 0)) {
                okay = true
            }
            else if (self.shiftScaledX > 0) {
                if [0, 1].contains(abs(self.shiftScaledX - (self.cellSizeScaled - self.shiftScaledXR))) {
                    okay = true
                }
            }
            print(String(format: "SHIFTSC(\(shiftx),\(shifty))> %.5fs" +
                                 " vw: [\(self._viewWidth)]" +
                                 " vwe: [\(self._viewWidthExtra)]" +
                                 " shc: [\(self.shiftCellX),\(shiftCellY)]" +
                                 " sh: [\(self.shiftScaledX),\(shiftScaledY)]" +
                                 " sh-u: [\(self.shiftX),\(self.shiftY)]" +
                                 " sht: [\(self.shifted(scaled: true).x),\(self.shifted(scaled: true).y)]" +
                                 " sht-u: [\(self.shifted.x),\(self.shifted.y)]" +
                                 " bm: \(self._bufferBlocks.memoryUsageBytes)" +
                                 " cs: \(self.cellSizeScaled)" +
                                 " cs-u: \(self.cellSize)" +
                                 " vc: \(self.viewColumns)" +
                                 " vce: \(self._viewColumnsExtra)" +
                                 " vcv: \(self.viewColumnsVisible)" +
                                 " vcev: \(self._viewColumnEndsVisible)" +
                                 " shr: \(self.shiftScaledXR)" +
                                 " ok: \(okay)",
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

        // TODO
        // after resize scalled up by 1 and then down by 1 gridCellLocation(viewCellX, viewCellY) = gridCellFromViewCellLocation
        // give okay result but not below ( i think ) ...
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

    public func save_resizeCells(cellSize: Int, adjustShift: Bool, scaled: Bool = false) {
        let cellSize: Int = !scaled ? self.scaled(cellSize) : cellSize
        if (cellSize != self.cellSizeScaled) {
            //
            // We need to get the new and current shift values here BEFORE the re-configure below,
            // for either contingency (i.e. where the resize takes, or not due to reaching the maximum
            // allowed cell size), because they  both depend on  the cell size which is updated by the re-configure.
            //
            let (shiftX, shiftY) = Zoom.calculateShiftForResizeCells(cellGridView: self, cellSize: cellSize, scaled: true)
            let shiftedCurrent: CellLocation = self.shifted(scaled: true)
            self.configureScaled(cellSize: cellSize,
                                 cellPadding: self.cellPaddingScaled,
                                 cellShape: self.cellShape,
                                 viewWidth: self.viewWidthScaled,
                                 viewHeight: self.viewHeightScaled,
                                 viewBackground: self.viewBackground,
                                 viewTransparency: self.viewTransparency,
                                 viewScaling: self.viewScaling)
            if (adjustShift && (cellSize == self.cellSizeScaled)) {
                self.shift(shiftx: shiftX, shifty: shiftY, scaled: true)
            }
            else {
                //
                // Here we must have reached the max cell-size (or adjustShift is false).
                //
                self.shift(shiftx: shiftedCurrent.x, shifty: shiftedCurrent.y, scaled: true)
            }
        }
    }

    public func resizeCells(cellSize: Int, adjustShift: Bool, scaled: Bool = false) {
        var cellSizeMax: Int = self.scaled(Defaults.cellSizeMax)
        var cellPadding: Int = self.scaled(self.cellPaddingScaled)
        var cellSizeInnerMin: Int = self.scaled(Defaults.cellSizeInnerMin)
        var cellSize = cellSize.clamped(cellSizeInnerMin + (cellPaddingScaled * 2)...cellSizeMax)
        if (cellSize != self.cellSizeScaled) {
            //
            // We need to get the new and current shift values here BEFORE the re-configure below, for
            // either contingency (i.e. where the resize takes, or not due to reaching the maximum allowed
            // cell size), because they  both depend on the cell size which is updated by the re-configure.
            // TODO: Think we can rework things so as not to require this ordering/dependency.
            //
            let (shiftX, shiftY) = Zoom.calculateShiftForResizeCells(cellGridView: self, cellSize: cellSize, scaled: true)
            let (shiftMaxX, shiftMaxY) = Zoom.calculateShiftForResizeCells(cellGridView: self, cellSize: Defaults.cellSizeMax, scaled: true)
            self.configureScaled(cellSize: cellSize,
                                 cellPadding: self.cellPaddingScaled,
                                 cellShape: self.cellShape,
                                 viewWidth: self.viewWidthScaled,
                                 viewHeight: self.viewHeightScaled,
                                 viewBackground: self.viewBackground,
                                 viewTransparency: self.viewTransparency,
                                 viewScaling: self.viewScaling)
            if (adjustShift && (cellSize == self.cellSizeScaled)) {
                self.shift(shiftx: shiftX, shifty: shiftY, scaled: true)
            }
            else {
                //
                // Here we must have reached the max cell-size (or adjustShift is false).
                //
                self.shift(shiftx: shiftMaxX, shifty: shiftMaxY, scaled: true)
            }
        }
    }
}
