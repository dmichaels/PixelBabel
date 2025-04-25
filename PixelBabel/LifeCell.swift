import SwiftUI

class LifeCell: Cell {

    public var _alive: Bool

    init(parent: Cells, x: Int, y: Int,  foreground: PixelValue? = nil, background: PixelValue? = nil, alive: Bool = false) {
        self._alive = alive
        super.init(parent: parent, x: x, y: y, foreground: foreground, background: background)
    }

    public var alive: Bool {
        get { self._alive }
        set { self._alive = newValue }
    }

    public static func define(parent: Cells, x: Int, y: Int) -> LifeCell {
        return LifeCell(parent: parent, x: x, y: y)
    }
}
