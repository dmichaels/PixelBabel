import Foundation
import Utils

extension CellGridView
{
    @MainActor
    public struct Zoom {

        public var cellGridView: CellGridView
        public var startCellSize: Int
        public var startShiftedX: Int
        public var startShiftedY: Int
        public var scaled: Bool

        public func zoom(_ zoom: CGFloat) {
            let cellSizeZoomed: CGFloat = CGFloat(self.startCellSize) * zoom
            let cellSize: Int = Int(cellSizeZoomed.rounded(FloatingPointRoundingRule.toNearestOrEven))
            let cellSizeIncrement: Int = cellSize - self.startCellSize
            // let (shiftX, shiftY) = self.calculateShiftForResizeCells(cellSize: cellSize, scaled: self.scaled)
            // cellGridView.resizeCells(cellSize: cellSize, shiftX: shiftX, shiftY: shiftY, scaled: self.scaled)
            cellGridView.resizeCells(cellSize: cellSize, adjustShift: true, scaled: self.scaled)
        }

        // TODO
        // OR maybe just use init; more straight-forward; thought there was but no real reason for static creation.
        //
        public static func start(cellGridView: CellGridView, zoom: CGFloat, scaled: Bool = false) -> Zoom {
            let shifted: CellLocation = scaled ? cellGridView.shifted(scaled: true) : cellGridView.shifted
            let zoomer: Zoom = Zoom(cellGridView: cellGridView,
                                    startCellSize: scaled ? cellGridView.cellSizeScaled : cellGridView.cellSize,
                                    startShiftedX: shifted.x,
                                    startShiftedY: shifted.y,
                                    scaled: scaled)
            zoomer.zoom(zoom)
            return zoomer
        }

        public func end(_ zoom: CGFloat) -> Zoom? {
            self.zoom(zoom)
            return nil
        }

        private func calculateShiftForResizeCells(cellSize: Int, scaled: Bool = false) -> (shiftx: Int, shifty: Int) {
            return Zoom.calculateShiftForResizeCells(cellGridView: self.cellGridView, cellSize: cellSize, scaled: scaled)
        }

        public static func calculateShiftForResizeCells(cellGridView: CellGridView, cellSize: Int, scaled: Bool = false) -> (shiftx: Int, shifty: Int) {

            let cellSize = !scaled ? cellGridView.scaled(cellSize) : cellSize
            let cellSizeCurrent: Int = cellGridView.cellSizeScaled
            let cellSizeIncrement: Int = cellSize - cellSizeCurrent
            guard cellSizeIncrement != 0 else { return (shiftx: 0, shifty: 0) }
            let shiftTotalCurrent: CellLocation = cellGridView.shifted(scaled: true)
            let shiftTotalAdjustedX: Int = adjustShiftTotal(viewSize: cellGridView.viewWidthScaled,
                                                            cellSize: cellSizeCurrent,
                                                            cellSizeIncrement: cellSizeIncrement,
                                                            shiftTotal: shiftTotalCurrent.x)
            let shiftTotalAdjustedY: Int = adjustShiftTotal(viewSize: cellGridView.viewHeightScaled,
                                                            cellSize: cellSizeCurrent,
                                                            cellSizeIncrement: cellSizeIncrement,
                                                            shiftTotal: shiftTotalCurrent.y)
            return !scaled ? (shiftx: cellGridView.unscaled(shiftTotalAdjustedX), shifty: cellGridView.unscaled(shiftTotalAdjustedY))
                           : (shiftx: shiftTotalAdjustedX, shifty: shiftTotalAdjustedY)
        }

        // Returns the adjusted total shift value for the given view size (width or height), cell size and the amount
        // it is being incremented by, and the current total shift value, so that the cells within the view remain
        // centered (where they were at the current/given cell size and shift total values) and after the cell size
        // has been adjusted by the given increment; this is the default behavior, but if a given view anchor factor
        // is specified, then the "center" of the view is taken to be the given view size times this given view anchor
        // factor (this is 0.5 by default giving the default centered behavior). This is only for handling zooming.
        //
        // This is tricky. Turns out it is literally impossible to compute this accurately for increments or more
        // than one without actually going through iteratively and computing the result one increment at a time,
        // due to the cummulative effects of rounding. Another possible solution is to define this function as
        // working properly only for increments of one, and when zooming if this function would otherwise be called
        // with increments greater than one, then manually manufacture zoom "events" for the intermediate steps,
        // i.e. call the resizeCells function iteratively; if we were worried about performance with this iteratively
        // looping solution here, that alternate solution would should be orders of magnitude less performant, but
        // the result might (might) look even smoother, or it could just make things seem slower and sluggish.
        //
        private static func adjustShiftTotal(viewSize: Int, cellSize: Int, cellSizeIncrement: Int, shiftTotal: Int,
                                             viewAnchorFactor: Double = 0.5) -> Int {
            let viewCenter: Double = Double(viewSize) * viewAnchorFactor
            let viewCenterAdjusted: Double = viewCenter - Double(shiftTotal)
            var cellSizeResult: Int = cellSize
            var shiftTotalResult: Int = shiftTotal
            let increment: Int = cellSizeIncrement > 0 ? 1 : -1
            for _ in 0..<abs(cellSizeIncrement){
                let shiftDelta: Double = (viewCenterAdjusted * Double(increment)) / Double(cellSizeResult)
                cellSizeResult += increment
                shiftTotalResult = Int(((cellSizeResult % 2 == 0) ? ceil : floor)(Double(shiftTotalResult) - shiftDelta))
            }
            return shiftTotalResult
        }

        private static func old_adjustShiftTotal(viewSize: Int, cellSize: Int, cellSizeIncrement: Int, shiftTotal: Int,
                                             viewAnchorFactor: Double = 0.5) -> Int {
            let viewCenter:          Double = Double(viewSize) * viewAnchorFactor
            let viewCenterAdjusted:  Double = viewCenter - Double(shiftTotal)
            let cellCenter:          Double = viewCenterAdjusted / Double(cellSize)
            let cellSizeIncremented: Int    = cellSize + cellSizeIncrement
            let shiftDelta:          Double = cellCenter * Double(cellSizeIncremented) - viewCenterAdjusted
            let round                       = ((cellSizeIncremented) % 2 == 0) ? ceil : floor
            return Int(round(Double(shiftTotal) - shiftDelta))
        }

        private static func older_adjustShiftTotal(viewSize: Int, cellSize: Int, cellSizeIncrement: Int, shiftTotal: Int,
                                                 viewAnchorFactor: Double = 0.5) -> Int {
            let viewCenter:         Double = Double(viewSize) * viewAnchorFactor
            let viewCenterAdjusted: Double = viewCenter - Double(shiftTotal)
            let cellCenter:         Double = viewCenterAdjusted / Double(cellSize)
            let shiftDelta:         Double = cellCenter * Double(cellSize + cellSizeIncrement) - viewCenterAdjusted
            return Int(round(Double(shiftTotal) - shiftDelta))
        }

        private static func oldest_adjustShiftTotal(viewSize: Int, cellSize: Int, cellSizeIncrement: Int,
                                                   shiftTotal: Int, viewAnchorFactor: Double = 0.5) -> Int {
            let viewCenter: Double = Double(viewSize) * viewAnchorFactor
            let round: (Double) -> Double = cellSizeIncrement > 0 ? (cellSize % 2 == 0 ? ceil : floor)
                                                                  : (cellSize % 2 == 0 ? floor : ceil)
            let cellsFromCenter: Int = Int(round((viewCenter - Double(shiftTotal)) / Double(cellSize)))
            return shiftTotal - (cellsFromCenter * cellSizeIncrement)
        }
    }
}
