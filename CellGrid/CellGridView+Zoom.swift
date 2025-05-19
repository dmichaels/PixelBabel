import Foundation

extension CellGridView
{
    @MainActor
    public struct Zoom {

        public var cellGridView: CellGridView
        public var startCellSize: Int
        public var startShiftedX: Int
        public var startShiftedY: Int
        public var startViewColumns: Int
        public var startViewRows: Int
        public var scaled: Bool

        public func zoom(_ zoom: CGFloat) {
            let cellSizeZoomed: CGFloat = CGFloat(self.startCellSize) * zoom
            let cellSize: Int = Int(cellSizeZoomed.rounded(FloatingPointRoundingRule.toNearestOrEven))
            let cellSizeIncrement: Int = cellSize - self.startCellSize
            let (shiftX, shiftY) = self.calculateShiftForResizeCells(cellSize: cellSize, scaled: self.scaled)
            cellGridView.resizeCells(cellSize: cellSize, shiftX: shiftX, shiftY: shiftY, scaled: self.scaled)
        }

        // TODO
        // OR maybe just use init; more straight-forwared; thought there was but no real reason for static creation.
        //
        public static func start(cellGridView: CellGridView, zoom: CGFloat, scaled: Bool = false) -> Zoom {
            let shifted: CellLocation = scaled ? cellGridView.shiftedByScaled : cellGridView.shiftedBy
            let zoomer: Zoom = Zoom(cellGridView: cellGridView,
                                    startCellSize: scaled ? cellGridView.cellSizeScaled : cellGridView.cellSize,
                                    startShiftedX: shifted.x,
                                    startShiftedY: shifted.y,
                                    startViewColumns: cellGridView.viewColumns,
                                    startViewRows: cellGridView.viewRows,
                                    scaled: scaled)
            zoomer.zoom(zoom)
            return zoomer
        }

        public func end(_ zoom: CGFloat) -> Zoom? {
            self.zoom(zoom)
            return nil
        }

        private func calculateShiftForResizeCells(cellSize: Int, scaled: Bool = false) -> (x: Int, y: Int) {
            let cellSizeCurrent: Int = scaled ? self.cellGridView.cellSizeScaled : self.cellGridView.cellSize 
            let cellSizeIncrement: Int = cellSize - cellSizeCurrent
            guard cellSizeIncrement != 0 else { return (x: 0, y: 0) }
            let shiftedCurrent: CellLocation = scaled ? self.cellGridView.shiftedByScaled : self.cellGridView.shiftedBy
            //
            // The addition of cellSize % 2 (either one or zero depending on the new cell-size being
            // odd or even) ensures we don't tend toward the right/left or down as we expand/shrink.
            //
            let fudgeShift: Int = cellSizeIncrement > 0 ? cellSize % 2 : -(cellSize % 2)
            //
            // TODO
            // Actually, we want the count of the number of FULLY visible cells, on the right/bottom
            // that is, i.e. if the left/top is only partially visible then we DO count it but if the
            // right/bottom is only partially visible then we do NOT count it. I THINK that's right.
            //
            let viewColumnsVisible: Int = self.cellGridView.viewColumnsVisible
            let viewRowsVisible: Int = self.cellGridView.viewRowsVisible
            let resultingShiftRight: Int = viewColumnsVisible * cellSizeIncrement + fudgeShift
            let resultingShiftDown: Int = viewRowsVisible * cellSizeIncrement + fudgeShift
            let shiftX: Int = shiftedCurrent.x - (resultingShiftRight / 2)
            let shiftY: Int = shiftedCurrent.y - (resultingShiftDown / 2)
            return (x: shiftX, y: shiftY)
        }
    }
}
