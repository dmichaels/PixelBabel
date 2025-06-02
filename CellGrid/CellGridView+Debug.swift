#if targetEnvironment(simulator)

import Foundation
import Utils

extension CellGridView
{
    func printSizes(viewWidthInit: Int = 0, viewHeightInit: Int = 0, cellSizeInit: Int = 0, cellSizeFitInit: Bool = false) {

        func scaled(_ value: Int) -> Int {
            //
            // Here so we can leave it as private in CellGridView.
            //
            return Screen.shared.scaled(value, scaling: self.viewScaling)
        }

        print("SCREEN>         \(scaled(Screen.shared.width)) x \(scaled(Screen.shared.height))" +
              (self.viewScaling ? " (unscaled: \(Screen.shared.width) x \(Screen.shared.height))" : "") +
              " | SCALE: \(Screen.shared.scale()) | SCALING: \(self.viewScaling)")
        if ((viewWidthInit > 0) && (viewHeightInit > 0)) {
            print("VIEW-SIZE-INI>  \(viewWidthInit) x \(viewHeightInit)" + (self.viewScaling ? " (unscaled)" : "") +
                  (viewWidthInit != self.viewWidth || viewHeightInit != self.viewHeight
                   ? " -> PREFERRED: \(self.viewWidth)" +
                     (" x \(self.viewHeight)" + (self.viewScaling ? " (unscaled)" : "")) : ""))
        }
        if (cellSizeInit > 0) {
            print("CELL-SIZE-INI>  \(cellSizeInit)" + (self.viewScaling ? " (unscaled)" : "") +
                   (cellSizeInit != self.cellSize
                    ? (" -> PREFERRED: \(self.cellSize)" + (self.viewScaling ? " (unscaled)" : "")) : ""))
        }
        print("VIEW-SIZE>      \(self.viewWidthScaled) x \(self.viewHeightScaled)" +
              (self.viewScaling ?
               " (unscaled: \(self.viewWidth) x \(self.viewHeight))" : ""))
        print("CELL-SIZE>      \(self.cellSizeScaled)" +
              (self.viewScaling ? " (unscaled: \(self.cellSize))" : ""))
        print("CELL-PADDING>   \(self.cellPaddingScaled)" +
              (self.viewScaling ? " (unscaled: \(self.cellPadding))" : ""))
        print("SHIFT>          [\(self.shiftTotalScaledX),\(self.shiftTotalScaledY)]" +
              (self.viewScaling ? " (unscaled: [\(self.shiftTotalX),\(self.shiftTotalY)])" : ""))
        if (cellSizeFitInit) {
            print("PREFERRED-SIZE> \(cellSizeFitInit)")
            let sizes = CellGridView.preferredSizes(viewWidth: self.viewWidth,
                                                    viewHeight: self.viewHeight)
            for size in sizes {
                print("PREFFERED>" +
                      " CELL-SIZE \(String(format: "%3d", scaled(size.cellSize)))" +
                      (self.viewScaling ? " (unscaled: \(String(format: "%3d", size.cellSize)))" : "") +
                      " VIEW-SIZE: \(String(format: "%3d", scaled(size.viewWidth)))" +
                      " x \(String(format: "%3d", scaled(size.viewHeight)))" +
                      (self.viewScaling ?
                       " (unscaled: \(String(format: "%3d", size.viewWidth))" +
                       " x \(String(format: "%3d", size.viewHeight)))" : "") +
                      " VIEW-MAR: \(String(format: "%2d", scaled(self.viewWidth) - scaled(size.viewWidth)))" +
                      " x \(String(format: "%2d", scaled(self.viewHeight) - scaled(size.viewHeight)))" +
                      (self.viewScaling ? (" (unscaled: \(String(format: "%2d", self.viewWidth - size.viewWidth))"
                                               + " x \(String(format: "%2d", self.viewHeight - size.viewHeight)))") : "") +
                      ((size.cellSize == self.cellSize) ? " <<<" : ""))
            }
        }
    }

    func printWriteCellsResult(_ start: Date) {
        let shiftOppositeScaled: Int = modulo(self.cellSizeScaled + self.shiftScaledX - self.viewWidthExtraScaled,
                                              self.cellSizeScaled)
        var even: Bool = false
        if [0, 1].contains(abs(abs(shiftOppositeScaled) - abs(self.shiftScaledX))) {
            even = true
        }
        else if ((self.shiftScaledX == -(self.cellSizeScaled - 1)) && (shiftOppositeScaled == 0)) {
            even = true
        }
        else if (self.shiftScaledX > 0) {
            if [0, 1].contains(abs(self.shiftScaledX - (self.cellSizeScaled - shiftOppositeScaled))) {
                even = true
            }
        }
        print(String(format: "SHIFT(\(shiftTotalX),\(shiftTotalY)) %.5f" +
                             (self.viewScaling ? " SC" : " US") +
                             " CS:\(self.cellSizeScaled)" +
                             " CSU:\(self.cellSize)" +
                             " SHT:\(self.shiftTotalScaledX),\(self.shiftTotalScaledY)" +
                             " SHTU:\(self.shiftTotalX),\(self.shiftTotalY)" +
                             " SHC:\(self.shiftCellScaledX),\(shiftCellScaledY)" +
                             " SHCU:\(self.shiftCellX),\(shiftCellY)" +
                             " SH:\(self.shiftScaledX),\(shiftScaledY)" +
                             " SHU:\(self.shiftX),\(self.shiftY)" +
                             " SHO:\(shiftOppositeScaled)" +
                             (even ? " EVEN" : " UNEVEN"),
              Date().timeIntervalSince(start)))
    }
}

#endif
