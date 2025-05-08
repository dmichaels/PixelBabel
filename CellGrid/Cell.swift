import Foundation
import SwiftUI

typealias CellFactory = (_ parent: CellGridView, _ x: Int, _ y: Int, _ foreground: CellColor, _ background: CellColor?) -> Cell

@MainActor
class Cell
{
    typealias Factory = (_ parent: Cells, _ x: Int, _ y: Int, _ foreground: CellColor, _ background: CellColor) -> Cell

    private let _parent: Cells?
    private let _viewParent: CellGridView?
    private let _x: Int
    private let _y: Int
    private var _foreground: CellColor
    //
    // TODO
    // Don't think we need background at this level; implementation detail.
    //
    private var _background: CellColor?

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

    public var background: CellColor {
        (self._background != nil)
        ? self._background!
        : ((self._viewParent != nil)
           ? self._viewParent!.viewBackground
           : ((self._parent != nil)
              ? self._parent!.background
              : CellColor(Color.black)))
    }

    init(parent: Cells, x: Int, y: Int, foreground: CellColor, background: CellColor?) {
        self._parent = parent
        self._viewParent = nil
        self._x = x
        self._y = y
        self._foreground = foreground
        self._background = background
    }

    init(viewParent: CellGridView, x: Int, y: Int, foreground: CellColor) {
        self._parent = nil
        self._viewParent = viewParent
        self._x = x
        self._y = y
        self._foreground = foreground
        self._background = nil
    }

    public func write(foreground: CellColor, foregroundOnly: Bool = false) {
        print("XYZZY-WRITE-A")
        self._foreground = foreground
        self._parent!.writeCell(x: self.x, y: self.y,
                                foreground: foreground,
                                background: background,
                                cellForegroundOnly: foregroundOnly)
    }

    public func write(foreground: CellColor, background: CellColor, foregroundOnly: Bool = false) {
        print("XYZZY-WRITE-B")
        self._foreground = foreground
        self._background = background
        self._parent!.writeCell(x: self.x, y: self.y,
                                foreground: foreground,
                                background: background,
                                cellForegroundOnly: foregroundOnly)
    }
}
