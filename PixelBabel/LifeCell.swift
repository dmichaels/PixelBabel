import SwiftUI

class LifeCell: Cell {

    public var _active: Bool
    public var _activeColor: CellColor
    public var _inactiveColor: CellColor

    init(parent: Cells, x: Int, y: Int, foreground: CellColor, background: CellColor,
         activeColor: CellColor, inactiveColor: CellColor, active: Bool = false) {
        self._active = active
        self._activeColor = activeColor
        self._inactiveColor = inactiveColor
        super.init(parent: parent, x: x, y: y, foreground: foreground, background: background)
    }

    public var active: Bool {
        self._active
    }

    public var inactive: Bool {
        !self._active
    }

    public func activate(noupdate: Bool = false) {
        self._active = true
        if (!noupdate)  {
            self.update()
        }
    }

    public func deactivate(noupdate: Bool = false) {
        self._active = false
        if (!noupdate)  {
            self.update()
        }
    }

    public func toggle(noupdate: Bool = false) -> Bool {
        self._active = !self._active
        if (!noupdate)  {
            self.update()
        }
        return self._active
    }

    private func update() {
        self.write(foreground: self._active ? self._activeColor : self._inactiveColor, background: self.background)
    }

    /*
    public static func factory(parent: Cells, x: Int, y: Int, foreground: CellColor, background: CellColor) -> Cell {
        return LifeCell(parent: parent, x: x, y: y, foreground: foreground, background: background)
    }
    */

    public static func factory(activeColor: CellColor, inactiveColor: CellColor) -> Cell.Factory {
        return { parent, x, y, foreground, background in
            return LifeCell(parent: parent, x: x, y: y, foreground: foreground, background: background,
                            activeColor: activeColor, inactiveColor: inactiveColor, active: false)
        }
    }
}
