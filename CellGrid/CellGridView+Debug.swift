import Utils

extension CellGridView
{
    func printSizes(viewWidthInit: Int = 0, viewHeightInit: Int = 0, cellSizeInit: Int = 0, cellFitInit: Bool = false) {
        print("SCREEN>                   \(self.scaled(Screen.shared.width)) x \(self.scaled(Screen.shared.height))" +
              (self.viewScaling ? " (unscaled: \(Screen.shared.width) x \(Screen.shared.height))" : "") +
              " | SCALE: \(Screen.shared.scale()) | SCALING: \(self.viewScaling)")
        if ((viewWidthInit > 0) && (viewHeightInit > 0)) {
            print("VIEW-SIZE-INITIAL>        \(viewWidthInit) x \(viewHeightInit)" + (self.viewScaling ? " (unscaled)" : "") +
                  (viewWidthInit != self.viewWidth || viewHeightInit != self.viewHeight
                   ? " -> PREFERRED: \(self.viewWidth)" +
                     (" x \(self.viewHeight)" + (self.viewScaling ? " (unscaled)" : "")) : ""))
        }
        if (cellSizeInit > 0) {
            print("CELL-SIZE-INITIAL>        \(cellSizeInit)" + (self.viewScaling ? " (unscaled)" : "") +
                   (cellSizeInit != self.cellSize
                    ? (" -> PREFERRED: \(self.cellSize)" + (self.viewScaling ? " (unscaled)" : "")) : ""))
        }
        print("VIEW-SIZE>                \(self.scaled(self.viewWidth)) x \(self.scaled(self.viewHeight))" +
              (self.viewScaling ?
               " (unscaled: \(self.viewWidth) x \(self.viewHeight))" : ""))
        print("CELL-SIZE>                \(self.scaled(self.cellSize))" +
              (self.viewScaling ? " (unscaled: \(self.cellSize))" : ""))
        print("CELL-PADDING>             \(self.scaled(self.cellPadding))" +
              (self.viewScaling ? " (unscaled: \(self.cellPadding))" : ""))
        print("PREFERRED-SIZING>         \(cellFitInit)")
        if (cellFitInit) {
            let sizes = CellGridView.preferredSizes(viewWidth: self.viewWidth,
                                                    viewHeight: self.viewHeight)
            for size in sizes {
                print("PREFFERED>" +
                      " CELL-SIZE \(String(format: "%3d", self.scaled(size.cellSize)))" +
                      (self.viewScaling ? " (unscaled: \(String(format: "%3d", size.cellSize)))" : "") +
                      " VIEW-SIZE: \(String(format: "%3d", self.scaled(size.viewWidth)))" +
                      " x \(String(format: "%3d", self.scaled(size.viewHeight)))" +
                      (self.viewScaling ?
                       " (unscaled: \(String(format: "%3d", size.viewWidth))" +
                       " x \(String(format: "%3d", size.viewHeight)))" : "") +
                      " MARGINS: \(String(format: "%2d", self.scaled(self.viewWidth) - self.scaled(size.viewWidth)))" +
                      " x \(String(format: "%2d", self.scaled(self.viewHeight) - self.scaled(size.viewHeight)))" +
                      (self.viewScaling ? (" (unscaled: \(String(format: "%2d", self.viewWidth - size.viewWidth))"
                                               + " x \(String(format: "%2d", self.viewHeight - size.viewHeight)))") : "") +
                      ((size.cellSize == self.cellSize) ? " <<<" : ""))
            }
        }
    }
}
