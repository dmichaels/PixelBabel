extension CellGridView {

    internal func defineGridCells(gridColumns: Int, gridRows: Int, foreground: CellColor) -> [Cell]
    {
        var gridCells: [Cell] = []
        for y in 0..<gridRows {
            for x in 0..<gridColumns {
                gridCells.append(self.createCell(x: x, y: y, foreground: foreground) ??
                                 Cell(cellGridView: self, x: x, y: y, foreground: foreground))
            }
        }
        return gridCells
    }
}
