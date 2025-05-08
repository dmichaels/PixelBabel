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

    init(parent: CellGridView, x: Int, y: Int, foreground: CellColor,
         activeColor: CellColor, inactiveColor: CellColor, active: Bool = false) {
        self._active = active
        self._activeColor = activeColor
        self._inactiveColor = inactiveColor
        super.init(viewParent: parent, x: x, y: y, foreground: foreground)
    }

    public var active: Bool {
        self._active
    }

    public var inactive: Bool {
        !self._active
    }

    public func activate(nowrite: Bool = false) {
        if (!self._active) {
            self._active = true
            if (!nowrite)  {
                self.write()
            }
        }
    }

    public func deactivate(nowrite: Bool = false) {
        if (self._active) {
            self._active = false
            if (!nowrite)  {
                self.write()
            }
        }
    }

    public func toggle(nowrite: Bool = false) {
        self._active ? self.deactivate(nowrite: nowrite) : self.activate(nowrite: nowrite)
    }

    func write() {
        self.write(foreground: self._active ? self._activeColor : self._inactiveColor, background: self.background)
    }

    public static func factory(activeColor: CellColor, inactiveColor: CellColor) -> Cell.Factory {
        return { parent, x, y, foreground, background in
            return LifeCell(parent: parent, x: x, y: y, foreground: foreground, background: background,
                            activeColor: activeColor, inactiveColor: inactiveColor, active: false)
        }
    }

    public static func factoryNew(activeColor: CellColor, inactiveColor: CellColor) -> CellFactory {
        return { parent, x, y, foreground in
            return LifeCell(parent: parent, x: x, y: y, foreground: foreground,
                            activeColor: activeColor, inactiveColor: inactiveColor, active: false)
        }
    }
}
