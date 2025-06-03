import Foundation
import SwiftUI

extension CellGridView
{
    @MainActor
    public class Actions
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

        public final func automationToggle() {
            if (self._automation) {
                self.automationStop()
                self._automation = false
            }
            else {
                self.automationStart()
                self._automation = true
            }
        }

        public final func automationStart() {
            self._automationTimer = Timer.scheduledTimer(withTimeInterval: self._automationInterval, repeats: true) { _ in
                self._cellGridView.automationStep()
            }
        }

        public final func automationStop() {
            if let automationTimer = self._automationTimer {
                automationTimer.invalidate()
                self._automationTimer = nil
            }
        }

        public final func onTap(_ viewPoint: CGPoint) {
            if let cell: Cell = self._cellGridView.gridCell(viewPoint: viewPoint) {
                cell.select()
                self._cellGridView.updateImage()
            }
        }

        public final func onLongTap(_ viewPoint: CGPoint) {
        }

        public final func onDoubleTap() {
            self._pickerMode = !self._pickerMode
        }

        public final func onDrag(_ viewPoint: CGPoint) {
            guard let dragger: CellGridView.Drag = self._dragger else {
                self._dragger = CellGridView.Drag(self._cellGridView, viewPoint, picker: self._pickerMode)
                return
            }
            dragger.drag(viewPoint)
            self._cellGridView.updateImage()
        }

        public final func onDragEnd(_ viewPoint: CGPoint) {
            if let dragger: CellGridView.Drag = self._dragger {
                dragger.end(viewPoint)
                self._dragger = nil
                self._cellGridView.updateImage()
            }
        }

        public final func onZoom(_ zoomFactor: CGFloat) {
            if let zoomer: CellGridView.Zoom = self._zoomer {
                zoomer.zoom(zoomFactor)
            }
            else {
                self._zoomer = CellGridView.Zoom(self._cellGridView, zoomFactor)
            }
            self._cellGridView.updateImage()
        }

        public final func onZoomEnd(_ zoomFactor: CGFloat) {
            if let zoomer: CellGridView.Zoom = self._zoomer {
                zoomer.end(zoomFactor)
                self._zoomer = nil
            }
        }
    }
}
