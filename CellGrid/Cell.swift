import Foundation

@MainActor
class Cell
{
    typealias Factory = (_ parent: Cells, _ x: Int, _ y: Int, _ foreground: CellColor, _ background: CellColor) -> Cell

    private let _parent: Cells
    private let _x: Int
    private let _y: Int
    private var _foreground: CellColor
    private var _background: CellColor

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
        self._foreground
    }

    public var background: CellColor {
        self._background
    }

    init(parent: Cells, x: Int, y: Int, foreground: CellColor, background: CellColor) {
        self._parent = parent
        self._x = x
        self._y = y
        self._foreground = foreground
        self._background = background
    }

    public func write(foreground: CellColor, limit: Bool = false) {
        self._foreground = foreground
        self._parent.writeCell(x: self.x, y: self.y, foreground: foreground, background: background, limit: limit)
    }

    public func write(foreground: CellColor, background: CellColor, limit: Bool = false) {
        self._foreground = foreground
        self._background = background
        self._parent.writeCell(x: self.x, y: self.y, foreground: foreground, background: background, limit: limit)
    }
}
