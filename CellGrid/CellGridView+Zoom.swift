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
            // cellGridView.resizeCells(cellSize: cellSize, shiftX: shiftX, shiftY: shiftY, scaled: self.scaled)
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

        private func calculateShiftForResizeCells(cellSize: Int, scaled: Bool = false) -> (shiftx: Int, shifty: Int) {
            return Zoom.calculateShiftForResizeCells(cellGridView: self.cellGridView, cellSize: cellSize, scaled: scaled)
        }

        public static func old_calculateShiftForResizeCells(cellGridView: CellGridView, cellSize: Int, scaled: Bool = false) -> (shiftx: Int, shifty: Int) {
            let cellSize = !scaled ? cellGridView.scaled(cellSize) : cellSize
            let cellSizeCurrent: Int = cellGridView.cellSizeScaled
            let cellSizeIncrement: Int = cellSize - cellSizeCurrent
            guard cellSizeIncrement != 0 else { return (shiftx: 0, shifty: 0) }
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
            // let viewRowsVisible: Int = cellGridView.viewRowsVisible
            let viewRowsVisible: Int = 20
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
            return !scaled ? (shiftx: cellGridView.unscaled(shiftX), shifty: cellGridView.unscaled(shiftY)) : (shiftx: shiftX, shifty: shiftY)
        }

        public static func calculateShiftForResizeCells(cellGridView: CellGridView, cellSize: Int, scaled: Bool = false) -> (shiftx: Int, shifty: Int) {
            let cellSize = !scaled ? cellGridView.scaled(cellSize) : cellSize
            let cellSizeCurrent: Int = cellGridView.cellSizeScaled
            let cellSizeIncrement: Int = cellSize - cellSizeCurrent
            guard cellSizeIncrement != 0 else { return (shiftx: 0, shifty: 0) }
            let shiftedCurrent: CellLocation = cellGridView.shifted(scaled: true)
            //
            // The addition of cellSize % 2 (either one or zero depending on the new cell-size being
            // odd or even) ensures we don't tend toward the right/left or down as we expand/shrink.
            //
            let fudgeShift: Int = (cellSizeIncrement > 0) ? (cellSize % 2) : -(cellSize % 2)

            // Weird this works  ...  setting viewColumnsVisible to hardcoded 9, for an initial
            // cellSize of 43 anyways (i.e. where the initial viewColumns is 9); but why???

            // let viewColumnsVisible: Int = 9 // cellGridView.viewColumnsVisible
            // let viewRowsVisible: Int = 20 // cellGridView.viewRowsVisible

            // Maybe use viewColumns for resultingShiftRight and then adjust current shift to be in the
            // context of newCellSize, so assuming viewWidth == 1161 (with initial cellSize == 43), and
            // implying viewColumns == 6 (i.e. 1161 / 167), and assuming currentCellSize == 166 and
            // newCellSize == 167, and then if the current shift values are:
            //
            //   shifted.x: -166 -> shiftCellX: -1 shiftX: 0
            //
            // then relative to the newCellSize (167) this is now:
            //
            //   shifted.x: -166 -> shiftCellX: 0 shiftX: -166
            //
            // which means we additionally are shifting right by cellSize + shiftX == 167 + -166 == 1,
            // so we have resultingShiftRight = viewColumns * cellSizeIncrement == 6 * 1 == 6, but then
            // we need to add this additional shift value (from the current shift value in the new context),
            // i.e. add 1 to 6 to get 7, but also our fudgeShift for 167 is 1 so that makes it 8, and then
            // dividing by 2 we get 4.
            //
            var relevantViewColumns: Int = cellGridView.viewColumnsVisible
            var relevantViewRows: Int = cellGridView.viewRowsVisible

            var additionalShiftX: Int = 0
            var additionalShiftY: Int = 0

            if (cellGridView.shiftCellX != 0) {
                relevantViewColumns += 1
                relevantViewRows += 1
                let currentShiftResizedX: Int = shiftedCurrent.x % cellSize // -166 for shiftCurrent.x == -166 and cellSize == 167
                let currentShiftResizedY: Int = shiftedCurrent.y % cellSize
                additionalShiftX = currentShiftResizedX != 0 ? cellSize + currentShiftResizedX : 0 // assuming is negative TODO otherwise
                additionalShiftY = currentShiftResizedY != 0 ? cellSize + currentShiftResizedY : 0
            }

            let resultingShiftRight: Int = relevantViewColumns * cellSizeIncrement + additionalShiftX + fudgeShift
            let resultingShiftDown: Int = relevantViewRows * cellSizeIncrement + additionalShiftY + fudgeShift

            let shiftX: Int = shiftedCurrent.x - (resultingShiftRight / 2)
            let shiftY: Int = shiftedCurrent.y - (resultingShiftDown / 2)

            let newViewWidthExtra = cellGridView.viewWidthScaled % cellSize
            let newShiftX = shiftX % cellSize
            let newShiftXR = modulo(cellSize + shiftX - newViewWidthExtra, cellSize)
            let okay = (abs(abs(newShiftX) - abs(newShiftXR)) == 0) || (abs(abs(newShiftX) - abs(newShiftXR)) == 1)

            print("RESIZE-CALC: cs: \(cellSize) ci: \(cellSizeIncrement) csc: \(cellSizeCurrent) vc: \(cellGridView.viewColumns) vcv: \(cellGridView.viewColumnsVisible) rvc: \(relevantViewColumns) sh: \(cellGridView.shiftScaledX) shc: \(cellGridView.shiftCellX) sht: \(shiftedCurrent.x) rsr: \(resultingShiftRight) f: \(fudgeShift) nvwe: \(newViewWidthExtra) > sh: \(newShiftX) shr: \(newShiftXR) OK: \(okay)")

            //
            // For debugging to get the right shift value (at least when shiftX is negative): 
            // cellSize - (viewWidth - ((viewWidth + shiftfX) - viewWidthExtra)) == cellSize + shiftX - viewWidthExtra
            //
            return !scaled ? (shiftx: cellGridView.unscaled(shiftX), shifty: cellGridView.unscaled(shiftY)) : (shiftx: shiftX, shifty: shiftY)
        }
    }
}
