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
            let (shiftX, shiftY) = self.calculateShiftForResizeCells(cellSize: cellSize, scaled: self.scaled)
            cellGridView.resizeCells(cellSize: cellSize, shiftX: shiftX, shiftY: shiftY, scaled: self.scaled)
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

        private func calculateShiftForResizeCells(cellSize: Int, scaled: Bool = false) -> (x: Int, y: Int) {
            return Zoom.calculateShiftForResizeCells(cellGridView: self.cellGridView, cellSize: cellSize, scaled: scaled)
        }

        public static func old_calculateShiftForResizeCells(cellGridView: CellGridView, cellSize: Int, scaled: Bool = false) -> (x: Int, y: Int) {
            let cellSizeCurrent: Int = scaled ? cellGridView.cellSizeScaled : cellGridView.cellSize 
            let cellSizeIncrement: Int = cellSize - cellSizeCurrent
            guard cellSizeIncrement != 0 else { return (x: 0, y: 0) }
            let shiftedCurrent: CellLocation = cellGridView.shifted(scaled: scaled)
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
            // let viewColumnsVisible: Int = cellGridView.viewColumnsVisible
            // let viewRowsVisible: Int = cellGridView.viewRowsVisible
            // let resultingShiftRight: Int = viewColumnsVisible * cellSizeIncrement + fudgeShift
            // let resultingShiftDown: Int = viewRowsVisible * cellSizeIncrement + fudgeShift

            // let resultingShiftRight: Int = cellGridView.viewColumnEndsVisible * cellSizeIncrement + fudgeShift
            // let resultingShiftDown: Int = cellGridView.viewRowEndsVisible * cellSizeIncrement + fudgeShift

            let resultingShiftRight: Int = cellGridView.viewColumnEndsVisible * cellSizeIncrement
            let resultingShiftDown: Int = cellGridView.viewRowEndsVisible * cellSizeIncrement

            // let shiftX: Int = shiftedCurrent.x - (resultingShiftRight / 2)
            // let shiftY: Int = shiftedCurrent.y - (resultingShiftDown / 2)

            let shiftX: Int = shiftedCurrent.x - (resultingShiftRight / 2) + fudgeShift
            let shiftY: Int = shiftedCurrent.y - (resultingShiftDown / 2) + fudgeShift

            return (x: shiftX, y: shiftY)
        }

        public static func calculateShiftForResizeCells(cellGridView: CellGridView, cellSize: Int, scaled: Bool = false) -> (x: Int, y: Int) {
            let cellSize = !scaled ? cellGridView.scaled(cellSize) : cellSize
            let cellSizeCurrent: Int = cellGridView.cellSizeScaled
            let cellSizeIncrement: Int = cellSize - cellSizeCurrent
            guard cellSizeIncrement != 0 else { return (x: 0, y: 0) }
            let shiftedCurrent: CellLocation = cellGridView.shifted(scaled: true)
            //
            // The addition of cellSize % 2 (either one or zero depending on the new cell-size being
            // odd or even) ensures we don't tend toward the right/left or down as we expand/shrink.
            //
            let fudgeShift: Int = (cellSizeIncrement > 0) ? (cellSize % 2) : -(cellSize % 2)
            // let fudgeShift: Int = (cellSizeIncrement > 0) ? (1 - (cellSize % 2)) : -(1 - (cellSize % 2))
            // let viewColumnsVisible: Int = cellGridView.viewColumnsVisible
            // let viewColumnsVisible: Int = cellGridView.viewColumnsVisible == 7 ? 9 : cellGridView.viewColumnsVisible
            // let viewColumnsVisible: Int = cellGridView.viewColumns
            //
            // Weird this works  ...  setting viewColumnsVisible to hardcoded 9, for an initial
            // cellSize of 43 anyways (i.e. where the initial viewColumns is 9); but why???
            //
            let viewColumnsVisible: Int = 9
            let viewRowsVisible: Int = cellGridView.viewRowsVisible
            let resultingShiftRight: Int = viewColumnsVisible * cellSizeIncrement + fudgeShift
            let resultingShiftDown: Int = viewRowsVisible * cellSizeIncrement + fudgeShift
            let shiftX: Int = shiftedCurrent.x - (resultingShiftRight / 2)
            let shiftY: Int = shiftedCurrent.y - (resultingShiftDown / 2)

            let newViewWidthExtra = cellGridView.viewWidthScaled % cellSize
            let newShiftX = shiftX % cellSize
            let newShiftXR = modulo(cellSize + shiftX - newViewWidthExtra, cellSize)
            let okay = (abs(abs(newShiftX) - abs(newShiftXR)) == 0) || (abs(abs(newShiftX) - abs(newShiftXR)) == 1)
            print("RESIZE-CALC: cs: \(cellSize) ci: \(cellSizeIncrement) csc: \(cellSizeCurrent) vc: \(cellGridView.viewColumns) vcv: \(viewColumnsVisible) shc: \(shiftedCurrent.x) rsr: \(resultingShiftRight) f: \(fudgeShift) nvwe: \(newViewWidthExtra) > sh: \(newShiftX) shr: \(newShiftXR) OK: \(okay)")

            //
            // For debugging to get the right shift value (at least when shiftX is negative): 
            // cellSize - (viewWidth - ((viewWidth + shiftfX) - viewWidthExtra)) == cellSize + shiftX - viewWidthExtra
            //
            return !scaled ? (x: cellGridView.unscaled(shiftX), y: cellGridView.unscaled(shiftY)) : (x: shiftX, y: shiftY)
        }
    }
}
