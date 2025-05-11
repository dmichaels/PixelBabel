import Foundation
import SwiftUI

typealias CellFactory = (_ parent: CellGridView, _ x: Int, _ y: Int, _ foreground: CellColor) -> Cell

@MainActor
class Cell
{
    private let _parent: CellGridView
    private let _x: Int
    private let _y: Int
    private var _foreground: CellColor

    public var x: Int {
        self._x
    }

    public var y: Int {
        self._y
    }

    public var location: CellGridPoint {
        CellGridPoint(self._x, self._y)
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
        self._foreground = foreground
        if let viewCellLocation = self._parent.viewCellFromGridCellLocation(self.x, self.y) {
            self._parent.writeCell(viewCellX: viewCellLocation.x, viewCellY: viewCellLocation.y)
        }
    }
}
