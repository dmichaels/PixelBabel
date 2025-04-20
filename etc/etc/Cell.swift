import Foundation

struct Cell {

    let x: Int
    let y: Int
    var parent: Cells

    init(x: Int, y: Int, parent: Cells) {
        self.x = x
        self.y = y
        self.parent = parent
    }

    public mutating func addBufferItem(_ index: Int, foreground: Bool, blend: Float = 0.0) {
        parent.addBufferItem(index, foreground: foreground, blend: blend)
    }

    public func write(_ buffer: inout [UInt8], foreground: PixelValue, background: PixelValue, limit: Bool = false) {
        parent.write(&buffer, x: self.x, y: self.y, foreground: foreground, background: background, limit: limit)
    }
}
