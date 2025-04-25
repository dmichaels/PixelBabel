import Foundation

class Cell {

    private let _parent: Cells
    private let _x: Int
    private let _y: Int
    private var _foreground: PixelValue
    private var _background: PixelValue

    public var x: Int {
        self._x
    }

    public var y: Int {
        self._y
    }

    public var location: GridPoint {
        GridPoint(self._x, self._y)
    }

    public var foreground: PixelValue {
        self._foreground
    }

    init(parent: Cells, x: Int, y: Int,  foreground: PixelValue? = nil, background: PixelValue? = nil) {
        self._parent = parent
        self._x = x
        self._y = y
        self._foreground = foreground ?? PixelValue.black
        self._background = background ?? PixelValue.white
    }

    public func addBufferItem(_ index: Int, foreground: Bool, blend: Float = 0.0) {
        self._parent.addBufferItem(index, foreground: foreground, blend: blend)
    }

    public func write(_ buffer: inout [UInt8], foreground: PixelValue, background: PixelValue, limit: Bool = false) {
        self._foreground = foreground
        self._background = background
        self._parent.write(&buffer, x: self.x, y: self.y, foreground: foreground, background: background, limit: limit)
    }
}
