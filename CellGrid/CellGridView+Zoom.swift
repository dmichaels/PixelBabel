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
            let shiftedCurrent: CellLocation = cellGridView.shifted(scaled: true)
            //
            // The addition of cellSize % 2 (either one or zero depending on the new cell-size being
            // odd or even) ensures we don't tend toward the right/left or down as we expand/shrink.
            //
            // let fudgeShift: Int = (cellSizeIncrement > 0) ? (cellSize % 2) : -(cellSize % 2)
            // let fudgeShift: Int = abs( (cellSizeIncrement > 0) ? (cellSize % 2) : -(cellSize % 2) )
            // let fudgeShift: Int = (cellSizeIncrement > 0) ? (cellSize % 2) : -(cellSize % 2)
            // let fudgeShift: Int = cellSize % 2
            let fudgeShift: Int = (cellSizeIncrement > 0) ? cellSize % 2 : -(1 - cellSize % 2) // yes i think so

            // Weird this works  ...  setting viewColumnsVisible to hardcoded 9, for an initial
            // cellSize of 43 anyways (i.e. where the initial viewColumns is 9); but why???
            //
            // let viewColumnsRelevant: Int = 9 // cellGridView.viewColumnsVisible
            // let viewRowsRelevant: Int = 20 // cellGridView.viewRowsVisible
            // let viewColumnsRelevant: Int = cellGridView._viewColumnsDebugInitial // 9
            // let viewRowsRelevant: Int = cellGridView._viewRowsDebugInitial // 20

            // let viewColumnsRelevant: Int = cellGridView._viewColumnsDebugInitial - cellGridView.shiftCellX
            // let viewRowsRelevant: Int = cellGridView._viewRowsDebugInitial - cellGridView.shiftCellY
            let viewColumnsRelevant: Int = cellGridView._viewColumnsDebugInitial // - cellGridView.shiftCellX
            let viewRowsRelevant: Int = cellGridView._viewRowsDebugInitial // - cellGridView.shiftCellY

            let resultingShiftRight: Int = viewColumnsRelevant * cellSizeIncrement + fudgeShift
            let resultingShiftDown: Int = viewRowsRelevant * cellSizeIncrement + fudgeShift

            let shiftX: Int = shiftedCurrent.x - (resultingShiftRight / 2)
            let shiftY: Int = shiftedCurrent.y - (resultingShiftDown / 2)

            let newViewWidthExtra = cellGridView.viewWidthScaled % cellSize
            let newShiftX = shiftX % cellSize
            let newShiftXR = modulo(cellSize + shiftX - newViewWidthExtra, cellSize)
            let okay = (abs(abs(newShiftX) - abs(newShiftXR)) == 0) || (abs(abs(newShiftX) - abs(newShiftXR)) == 1)

            print("RCALC> cs: \(cellSize) ci: \(cellSizeIncrement) | ccs: \(cellSizeCurrent) csht: \(shiftedCurrent.x) csh: \(cellGridView.shiftScaledX) cshc: \(cellGridView.shiftCellX) vc: \(cellGridView.viewColumns) vcv: \(cellGridView.viewColumnsVisible) vcr: \(viewColumnsRelevant) rsr: \(resultingShiftRight) shd: \(resultingShiftRight / 2) f: \(fudgeShift) nvwe: \(newViewWidthExtra) -> sh: \(newShiftX) shr: \(newShiftXR) -> " + (okay ? "OK" : "NOT-OK"))

            //
            // For debugging to get the right shift value (at least when shiftX is negative): 
            // cellSize - (viewWidth - ((viewWidth + shiftfX) - viewWidthExtra)) == cellSize + shiftX - viewWidthExtra
            //
            return !scaled ? (shiftx: cellGridView.unscaled(shiftX), shifty: cellGridView.unscaled(shiftY)) : (shiftx: shiftX, shifty: shiftY)
        }
    }
}
