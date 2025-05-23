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
            // let fudgeShift: Int = (cellSizeIncrement > 0) ? (cellSize % 2) : -(cellSize % 2)
            // let fudgeShift: Int = abs( (cellSizeIncrement > 0) ? (cellSize % 2) : -(cellSize % 2) )
            // let fudgeShift: Int = (cellSizeIncrement > 0) ? (cellSize % 2) : -(cellSize % 2)
            // let fudgeShift: Int = cellSize % 2

            // FYI DONT FORGET TO IGNORE NOT-OK  MESSAGES LIKE:
            // RCALC> cs: 232 ci: -1 | ccs: 233 csht: -468 csh: -2 cshc: -2 vc: 4 vcv: 5 vcr: 9 rsr: -10 shd: -5 f: -1 nvwe: 1 -> sh: -231 shr: 0 -> NOT-OK

            // ------------------------------------------------------------------------------------------------------------------------
            // THIS ARRANGEMENT WORKS WITH NO INITIAL SHIFT UP AND DOWN ....
            // But won't work with initial shift because need to add to viewColumnsInitial
            //
            // let fudgeShift: Int = (cellSizeIncrement > 0) ? cellSize % 2 : -(1 - cellSize % 2) // yes i think so
            // let viewColumnsRelevant: Int = cellGridView._viewColumnsDebugInitial
            // let viewRowsRelevant: Int = cellGridView._viewRowsDebugInitial
            // ------------------------------------------------------------------------------------------------------------------------

            // ------------------------------------------------------------------------------------------------------------------------
            // THIS ARRANGEMENT PARTIALLY WORKS WITH NO INITIAL SHIFT UP AND DOWN ....
            // let viewColumnsRelevant: Int = cellGridView._viewColumnsDebugInitial - cellGridView.shiftCellX
            // let fudgeShift: Int = <various-see-below>

            // FAILS AT:
            // RCALC> cs: 169 ci: 1 | ccs: 168 csht: -176 csh: -8 cshc: -1 vc: 6 vcv: 7 vcr: 10 rsr: 11 shd: 5 f: 1 nvwe: 147 -> sh: -12 shr: 10 -> NOT-OK
            // let fudgeShift: Int = (cellSizeIncrement > 0) ? cellSize % 2 : -(1 - cellSize % 2) // yes i think so

            // FAILS AT:
            // RCALC> cs: 233 ci: 1 | ccs: 232 csht: -463 csh: -231 cshc: -1 vc: 5 vcv: 6 vcr: 10 rsr: 10 shd: 5 f: 0 nvwe: 229 -> sht: -468 shc: -2 sh: -2 shr: 2 -> OK
            // RCALC> cs: 234 ci: 1 | ccs: 233 csht: -468 csh: -2 cshc: -2 vc: 4 vcv: 5 vcr: 11 rsr: 10 shd: 5 f: -1 nvwe: 225 -> sht: -473 shc: -2 sh: -5 shr: 4 -> OK-BUT-NOT-REALLY
            // RCALC> cs: 235 ci: 1 | ccs: 234 csht: -473 csh: -5 cshc: -2 vc: 4 vcv: 5 vcr: 11 rsr: 11 shd: 5 f: 0 nvwe: 221 -> sht: -478 shc: -2 sh: -8 shr: 6 -> NOT-OK
            // Including OK-BUT-NOT-REALLY ones above because it goes bad on cs:234 since when sh and shr differ the shr
            // should always be greater i.e. for cs:234 we should not get sh:-5 shr:4 but rather sh:-4 sh:5 ...
            let fudgeShift: Int = (cellGridView.shiftCellX == 0) 
                                  ? ((cellSizeIncrement > 0) ? cellSize % 2 : -(1 - cellSize % 2))
                                  : ((cellSizeIncrement < 0) ? cellSize % 2 : -(1 - cellSize % 2))
            // THIS ONE IS MOST PROMISING ... GOT THIS FAR INDICATES A DIFFERENT PROBLEM ... MAYBE ...

            // FAILS AT:
            // RCALC> cs: 169 ci: 1 | ccs: 168 csht: -176 csh: -8 cshc: -1 vc: 6 vcv: 7 vcr: 10 rsr: 10 shd: 5 f: 0 nvwe: 147 -> sh: -12 shr: 10 -> NOT-OK
            // let fudgeShift: Int = (cellGridView.shiftCellX == 0) 
            //                       ? ((cellSizeIncrement > 0) ? cellSize % 2 : -(1 - cellSize % 2))
            //                       : ((cellSizeIncrement < 0) ? cellSize % 2 :  (1 - cellSize % 2))

            // FAILS AT:
            // RCALC> cs: 167 ci: 1 | ccs: 166 csht: -166 csh: 0 cshc: -1 vc: 6 vcv: 7 vcr: 10 rsr: 9 shd: 4 f: -1 nvwe: 159 -> sh: -3 shr: 5 -> NOT-OK
            // let fudgeShift: Int = (cellGridView.shiftCellX == 0) 
            //                       ? ((cellSizeIncrement > 0) ? cellSize % 2 : -(1 - cellSize % 2))
            //                       : ((cellSizeIncrement < 0) ? cellSize % 2 : -(cellSize % 2))

            // FAILS AT:
            // RCALC> cs: 169 ci: 1 | ccs: 168 csht: -176 csh: -8 cshc: -1 vc: 6 vcv: 7 vcr: 10 rsr: 11 shd: 5 f: 1 nvwe: 147 -> sh: -12 shr: 10 -> NOT-OK
            // let fudgeShift: Int = (cellGridView.shiftCellX == 0) 
            //                       ? ((cellSizeIncrement > 0) ? cellSize % 2 : -(1 - cellSize % 2))
            //                       : ((cellSizeIncrement < 0) ? cellSize % 2 : cellSize % 2)

            // FAILS AT:
            // RCALC> cs: 169 ci: 1 | ccs: 168 csht: -176 csh: -8 cshc: -1 vc: 6 vcv: 7 vcr: 10 rsr: 11 shd: 5 f: 1 nvwe: 147 -> sh: -12 shr: 10 -> NOT-OK
            // let fudgeShift: Int = (cellGridView.shiftCellX == 0) 
            //                       ? ((cellSizeIncrement > 0) ? cellSize % 2 : -(1 - cellSize % 2))
            //                       : ((cellSizeIncrement < 0) ? -(1 - cellSize % 2) : cellSize % 2)

            // FAILS AT:
            // RCALC> cs: 167 ci: 1 | ccs: 166 csht: -166 csh: 0 cshc: -1 vc: 6 vcv: 7 vcr: 10 rsr: 9 shd: 4 f: -1 nvwe: 159 -> sh: -3 shr: 5 -> NOT-OK
            // let fudgeShift: Int = (cellGridView.shiftCellX == 0) 
            //                       ? ((cellSizeIncrement > 0) ? cellSize % 2 : -(1 - cellSize % 2))
            //                       : ((cellSizeIncrement < 0) ? (1 - cellSize % 2) : -(cellSize % 2))
            // ------------------------------------------------------------------------------------------------------------------------

            // ------------------------------------------------------------------------------------------------------------------------
            // TRY THIS ARRANGEMENT ...
            // let viewColumnsRelevant: Int = cellGridView._viewColumnsDebugInitial - (cellGridView.shiftCellX != 0 ? 1 : 0)
            // ------------------------------------------------------------------------------------------------------------------------

            // Weird this works  ...  setting viewColumnsVisible to hardcoded 9, for an initial
            // cellSize of 43 anyways (i.e. where the initial viewColumns is 9); but why???
            //
            // let viewColumnsRelevant: Int = 9 // cellGridView.viewColumnsVisible
            // let viewRowsRelevant: Int = 20 // cellGridView.viewRowsVisible
            // let viewColumnsRelevant: Int = cellGridView._viewColumnsDebugInitial // 9
            // let viewRowsRelevant: Int = cellGridView._viewRowsDebugInitial // 20

            // let viewColumnsRelevant: Int = cellGridView._viewColumnsDebugInitial
            // let viewRowsRelevant: Int = cellGridView._viewRowsDebugInitial
            // let viewColumnsRelevant: Int = cellGridView._viewColumnsDebugInitial - cellGridView.shiftCellX
            let viewColumnsRelevant: Int = cellGridView._viewColumnsDebugInitial + (cellGridView.shiftCellX != 0 ? 1 : 0)
            let viewRowsRelevant: Int = cellGridView._viewRowsDebugInitial - cellGridView.shiftCellY

            let resultingShiftRight: Int = viewColumnsRelevant * cellSizeIncrement + fudgeShift
            let resultingShiftDown: Int = viewRowsRelevant * cellSizeIncrement + fudgeShift

            let shiftX: Int = shiftedCurrent.x - (resultingShiftRight / 2)
            let shiftY: Int = shiftedCurrent.y - (resultingShiftDown / 2)

            let newViewWidthExtra = cellGridView.viewWidthScaled % cellSize
            let newShiftX = shiftX % cellSize
            let newShiftCellX = shiftX / cellSize
            let newShiftXR = modulo(cellSize + shiftX - newViewWidthExtra, cellSize)
            let okay = (abs(abs(newShiftX) - abs(newShiftXR)) == 0) || (abs(abs(newShiftX) - abs(newShiftXR)) == 1)
            let okaybutnotreally = (abs(abs(newShiftX) - abs(newShiftXR)) == 1) && (abs(newShiftX) > abs(newShiftXR)) ? "-BUT-NOT-REALLY" : ""

            print("RCALC> cs: \(cellSize) ci: \(cellSizeIncrement) | ccs: \(cellSizeCurrent) csht: \(shiftedCurrent.x) csh: \(cellGridView.shiftScaledX) cshc: \(cellGridView.shiftCellX) vc: \(cellGridView.viewColumns) vcv: \(cellGridView.viewColumnsVisible) vcr: \(viewColumnsRelevant) rsr: \(resultingShiftRight) shd: \(resultingShiftRight / 2) f: \(fudgeShift) nvwe: \(newViewWidthExtra) -> sht: \(shiftX) shc: \(newShiftCellX) sh: \(newShiftX) shr: \(newShiftXR) -> " + (okay ? "OK" + okaybutnotreally : "NOT-OK"))

            //
            // For debugging to get the right shift value (at least when shiftX is negative): 
            // cellSize - (viewWidth - ((viewWidth + shiftfX) - viewWidthExtra)) == cellSize + shiftX - viewWidthExtra
            //
            return !scaled ? (shiftx: cellGridView.unscaled(shiftX), shifty: cellGridView.unscaled(shiftY)) : (shiftx: shiftX, shifty: shiftY)
        }

        public static func calculateShiftForResizeCells(cellGridView: CellGridView, cellSize: Int, scaled: Bool = false) -> (shiftx: Int, shifty: Int) {

            // Returns the adjusted total shift value for the given view size (width or height), cell size and the amount
            // it is being incremented by, and the current total shift value, so that the cells within the view remain
            // centered after the cell size adjusted by the give increment; this is the default behavior, but if a
            // given view anchor factor is specified, then the "center" of the view is taken to be the given view
            // size times this given view anchor factor (this is 0.5 by default giving the default centered behavior).
            //
            func older_adjustShiftTotal(viewSize: Int, cellSize: Int, cellSizeIncrement: Int, shiftTotal: Int) -> Int {
                let viewAnchorFactor: Double = 0.5
                let viewCenter: Double = Double(viewSize) * viewAnchorFactor
                let cellsFromCenter: Int = Int(floor((viewCenter - Double(shiftTotal)) / Double(cellSize)))
                return shiftTotal - (cellsFromCenter * cellSizeIncrement)
            }
            func old_adjustShiftTotal(viewSize: Int, cellSize: Int, cellSizeIncrement: Int, shiftTotal: Int) -> Int {
                let viewAnchorFactor: Double = 0.5
                let viewCenter: Double = Double(viewSize) * viewAnchorFactor
                let round = cellSize % 2 == 0 ? ceil : floor
                let cellsFromCenter: Int = Int(round((viewCenter - Double(shiftTotal)) / Double(cellSize)))
                return shiftTotal - (cellsFromCenter * cellSizeIncrement)
            }
            func adjustShiftTotal(viewSize: Int, cellSize: Int, cellSizeIncrement: Int, shiftTotal: Int) -> Int {
                let viewAnchorFactor: Double = 0.5
                let viewCenter: Double = Double(viewSize) * viewAnchorFactor
                let round = cellSizeIncrement > 0 ? (cellSize % 2 == 0 ? ceil : floor) : (cellSize % 2 == 0 ? floor : ceil)
                let cellsFromCenter: Int = Int(round((viewCenter - Double(shiftTotal)) / Double(cellSize)))
                return shiftTotal - (cellsFromCenter * cellSizeIncrement)
            }

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
    }
}
