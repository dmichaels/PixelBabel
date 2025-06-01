class LifeCellGrid: CellGrid {

    public override func run() {
        self.nextGeneration()
    }

    private func nextGeneration() {
        guard let cellGridView = self.cellGridView else {
            return
        }
        var states: [[Bool]] = Array(repeating: Array(repeating: false, count: cellGridView.gridColumns), count: cellGridView.gridRows)
        for row in 0..<cellGridView.gridRows {
            for column in 0..<cellGridView.gridColumns {
                if let cell: LifeCell = cellGridView.gridCell(column, row) {
                    let liveNeighbors: Int = self.activeNeighbors(cell)
                    if cell.active {
                        states[row][column] = ((liveNeighbors == 2) || (liveNeighbors == 3))
                    } else {
                        states[row][column] = (liveNeighbors == 3)
                    }
                }
            }
        }
        for row in 0..<cellGridView.gridRows {
            for column in 0..<cellGridView.gridColumns {
                if let cell: LifeCell = cellGridView.gridCell(column, row) {
                    if (states[row][column]) {
                        cell.activate()
                    }
                    else {
                        cell.deactivate()
                    }
                }
            }
        }
    }

    private func activeNeighbors(_ cell: LifeCell) -> Int {
        guard let cellGridView = self.cellGridView else {
            return 0
        }
        var count = 0
        for dy in -1...1 {
            for dx in -1...1 {
                if ((dx == 0) && (dy == 0)) {
                    continue
                }
                let nx = (cell.x + dx + cellGridView.gridColumns) % cellGridView.gridColumns
                let ny = (cell.y + dy + cellGridView.gridRows) % cellGridView.gridRows
                if let cell: LifeCell = cellGridView.gridCell(nx, ny) {
                    if (cell.active) {
                        count += 1
                    }
                }
            }
        }
        return count
    }
}
