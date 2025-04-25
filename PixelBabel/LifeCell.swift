import SwiftUI

class LifeCell: Cell {

    public let alive: Bool

    init(parent: Cells, x: Int, y: Int,  foreground: PixelValue? = nil, background: PixelValue? = nil, alive: Bool = false) {
        self.alive = alive
        super.init(parent: parent, x: x, y: y, foreground: foreground, background: background)
    }

    public static func define(parent: Cells, x: Int, y: Int) -> LifeCell {
        return LifeCell(parent: parent, x: x, y: y)
    }
}
