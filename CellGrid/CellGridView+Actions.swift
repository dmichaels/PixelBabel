import Foundation
import SwiftUI

extension CellGridView
{
    public class ActionData
    {
        internal var _dragger: CellGridView.Drag? = nil
        internal var _zoomer: CellGridView.Zoom? = nil
        internal var _pickerMode: Bool = false
    }

    public func onTap(_ viewPoint: CGPoint) {
        if let cell: Cell = self.gridCell(viewPoint: viewPoint) {
            cell.select()
            self._updateImage()
        }
    }

    public func onLongTap(_ viewPoint: CGPoint) {
    }

    public func onDoubleTap() {
        self._actionData._pickerMode = !self._actionData._pickerMode
    }

    public func onDrag(_ viewPoint: CGPoint) {
        guard let dragger: CellGridView.Drag = self._actionData._dragger else {
            self._actionData._dragger = CellGridView.Drag(self, viewPoint, picker: self._actionData._pickerMode)
            return
        }
        dragger.drag(viewPoint)
        self._updateImage()
    }

    public func onDragEnd(_ viewPoint: CGPoint) {
        if let dragger: CellGridView.Drag = self._actionData._dragger {
            dragger.end(viewPoint)
            self._updateImage()
            self._actionData._dragger = nil
        }
    }

    public func onZoom(_ zoomFactor: CGFloat) {
        guard let zoomer: CellGridView.Zoom = self._actionData._zoomer else {
            self._actionData._zoomer = CellGridView.Zoom(self, zoomFactor)
            self._updateImage()
            return
        }
        zoomer.zoom(zoomFactor)
        self._updateImage()
    }

    public func onZoomEnd(_ zoomFactor: CGFloat) {
        if let zoomer: CellGridView.Zoom = self._actionData._zoomer {
            zoomer.end(zoomFactor)
            self._actionData._zoomer = nil
        }
    }
}
