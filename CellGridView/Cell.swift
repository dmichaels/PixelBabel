import Foundation
import SwiftUI

// @MainActor
class Cell
{
    private var _cellGridView: CellGridView
    private let _x: Int
    private let _y: Int
    private var _foreground: CellColor

    public var x: Int {
        self._x
    }

    public var y: Int {
        self._y
    }

    public var location: CellLocation {
        CellLocation(self._x, self._y)
    }

    public var foreground: CellColor {
        get { return self._foreground }
        set { self._foreground = newValue }
    }

    init(cellGridView: CellGridView, x: Int, y: Int, foreground: CellColor) {
        self._cellGridView = cellGridView
        self._x = x
        self._y = y
        self._foreground = foreground
    }

    public func select(dragging: Bool = false) {
        //
        // To be implemented by subclasses.
        //
    }

    public func write(foreground: CellColor, foregroundOnly: Bool = false) {
        if let viewCellLocation = self._cellGridView.viewCellLocation(gridCellX: self._x, gridCellY: self._y) {
            self._foreground = foreground
            self._cellGridView.writeCell(viewCellX: viewCellLocation.x, viewCellY: viewCellLocation.y)
        }
    }
}
