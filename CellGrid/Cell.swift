import Foundation
import SwiftUI

@MainActor
class Cell
{
    private var _parent: CellGridView
    private let _x: Int
    private let _y: Int
    private var _foreground: CellColor

    typealias Factory = (_ parent: CellGridView, _ x: Int, _ y: Int, _ foreground: CellColor) -> Cell

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

    init(parent: CellGridView, x: Int, y: Int, foreground: CellColor) {
        self._parent = parent
        self._x = x
        self._y = y
        self._foreground = foreground
    }

    public func write(foreground: CellColor, foregroundOnly: Bool = false) {
        if let viewCellLocation = self._parent.viewCellFromGridCellLocation(self._x, self._y) {
            self._foreground = foreground
            self._parent.writeCell(viewCellX: viewCellLocation.x, viewCellY: viewCellLocation.y)
        }
    }
}
