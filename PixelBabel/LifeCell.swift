import SwiftUI

class LifeCell: Cell {

    public var _active: Bool

    init(parent: CellGridView, x: Int, y: Int, foreground: CellColor, active: Bool = false) {
        self._active = active
        super.init(parent: parent, x: x, y: y, foreground: foreground)
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
        // TODO
        self.write(foreground: CellColor(Color.black))
    }

    public static func factory() -> CellFactory {
        return { parent, x, y, foreground in
            return LifeCell(parent: parent, x: x, y: y, foreground: foreground, active: false)
        }
    }
}
