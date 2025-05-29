//
//  CellGridView+GridCells.swift
//  PixelBabel
//
//  Created by David Michaels on 5/29/25.
//

extension CellGridView {

    internal func defineGridCells(gridColumns: Int, gridRows: Int,
                                  gridCellFactory: Cell.Factory?, foreground: CellColor) -> [Cell]
    {
        var gridCells: [Cell] = []
        for y in 0..<gridRows {
            for x in 0..<gridColumns {
                gridCells.append(gridCellFactory?(self, x, y, foreground) ??
                                 Cell(parent: self, x: x, y: y, foreground: foreground))
            }
        }
        return gridCells
    }
    
}
