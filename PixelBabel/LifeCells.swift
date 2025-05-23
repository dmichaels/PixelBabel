import SwiftUI

extension CellGridView {

    func nextGeneration() {
        var states: [[Bool]] = Array(repeating: Array(repeating: false, count: self.gridColumns), count: self.gridRows)
        for row in 0..<self.gridRows {
            for column in 0..<self.gridColumns {
                if let cell: LifeCell = self.gridCell(column, row) {
                    let liveNeighbors: Int = self.activeNeighbors(cell)
                    if cell.active {
                        states[row][column] = ((liveNeighbors == 2) || (liveNeighbors == 3))
                    } else {
                        states[row][column] = (liveNeighbors == 3)
                    }
                }
            }
        }
        for row in 0..<self.gridRows {
            for column in 0..<self.gridColumns {
                if let cell: LifeCell = self.gridCell(column, row) {
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

    func activeNeighbors(_ cell: LifeCell) -> Int {
        var count = 0
        for dy in -1...1 {
            for dx in -1...1 {
                if ((dx == 0) && (dy == 0)) {
                    continue
                }
                let nx = (cell.x + dx + self.gridColumns) % self.gridColumns
                let ny = (cell.y + dy + self.gridRows) % self.gridRows
                if let cell: LifeCell = self.gridCell(nx, ny) {
                    if (cell.active) {
                        count += 1
                    }
                }
            }
        }
        return count
    }
}
