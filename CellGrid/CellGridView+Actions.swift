import Foundation
import SwiftUI

extension CellGridView
{
    public class Actions
    {
        internal var _dragger: CellGridView.Drag? = nil
        internal var _zoomer: CellGridView.Zoom? = nil
        internal var _pickerMode: Bool = false
    }

    public func onTap(_ viewPoint: CGPoint) {
        if let cell: Cell = self.gridCell(viewPoint: viewPoint) {
            cell.select()
            self.updateImage()
        }
    }

    public func onLongTap(_ viewPoint: CGPoint) {
    }

    public func onDoubleTap() {
        self._actions._pickerMode = !self._actions._pickerMode
    }

    public func onDrag(_ viewPoint: CGPoint) {
        guard let dragger: CellGridView.Drag = self._actions._dragger else {
            self._actions._dragger = CellGridView.Drag(self, viewPoint, picker: self._actions._pickerMode)
            return
        }
        dragger.drag(viewPoint)
        self.updateImage()
    }

    public func onDragEnd(_ viewPoint: CGPoint) {
        if let dragger: CellGridView.Drag = self._actions._dragger {
            dragger.end(viewPoint)
            self.updateImage()
            self._actions._dragger = nil
        }
    }

    public func onZoom(_ zoomFactor: CGFloat) {
        guard let zoomer: CellGridView.Zoom = self._actions._zoomer else {
            self._actions._zoomer = CellGridView.Zoom(self, zoomFactor)
            self.updateImage()
            return
        }
        zoomer.zoom(zoomFactor)
        self.updateImage()
    }

    public func onZoomEnd(_ zoomFactor: CGFloat) {
        if let zoomer: CellGridView.Zoom = self._actions._zoomer {
            zoomer.end(zoomFactor)
            self._actions._zoomer = nil
        }
    }
}
