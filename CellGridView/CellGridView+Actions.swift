import Foundation
import SwiftUI

extension CellGridView
{
    public final class Actions
    {
        private let _cellGridView: CellGridView
        private let _automationInterval: Double
        private var _automation: Bool = false
        private var _automationTimer: Timer? = nil
        private var _dragger: CellGridView.Drag? = nil
        private var _zoomer: CellGridView.Zoom? = nil
        private var _pickerMode: Bool = false

        public init(_ cellGridView: CellGridView, automationInterval: Double = DefaultSettings.automationInterval) {
            self._cellGridView = cellGridView
            self._automationInterval = automationInterval
        }

        public func automationToggle() {
            if (self._automation) {
                self.automationStop()
                self._automation = false
            }
            else {
                self.automationStart()
                self._automation = true
            }
        }

        public func automationStart() {
            self._automationTimer = Timer.scheduledTimer(withTimeInterval: self._automationInterval, repeats: true) { _ in
                self._cellGridView.automationStep()
            }
        }

        public func automationStop() {
            if let automationTimer = self._automationTimer {
                automationTimer.invalidate()
                self._automationTimer = nil
            }
        }

        public func onTap(_ viewPoint: CGPoint) {
            if let cell: Cell = self._cellGridView.gridCell(viewPoint: viewPoint) {
                cell.select()
                self._cellGridView.updateImage()
            }
        }

        public func onLongTap(_ viewPoint: CGPoint) {
        }

        public func onDoubleTap() {
            self._pickerMode = !self._pickerMode
        }

        public func onDrag(_ viewPoint: CGPoint) {
            guard let dragger: CellGridView.Drag = self._dragger else {
                self._dragger = CellGridView.Drag(self._cellGridView, viewPoint, picker: self._pickerMode)
                return
            }
            dragger.drag(viewPoint)
            self._cellGridView.updateImage()
        }

        public func onDragEnd(_ viewPoint: CGPoint) {
            if let dragger: CellGridView.Drag = self._dragger {
                dragger.end(viewPoint)
                self._dragger = nil
                self._cellGridView.updateImage()
            }
        }

        public func onZoom(_ zoomFactor: CGFloat) {
            if let zoomer: CellGridView.Zoom = self._zoomer {
                zoomer.zoom(zoomFactor)
            }
            else {
                self._zoomer = CellGridView.Zoom(self._cellGridView, zoomFactor)
            }
            self._cellGridView.updateImage()
        }

        public func onZoomEnd(_ zoomFactor: CGFloat) {
            if let zoomer: CellGridView.Zoom = self._zoomer {
                zoomer.end(zoomFactor)
                self._zoomer = nil
            }
        }
    }
}
