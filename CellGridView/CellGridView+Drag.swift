import Foundation
import Utils

extension CellGridView
{
    @MainActor
    public struct Drag
    {
        private let _cellGridView: CellGridView
        private let _startX: Int
        private let _startY: Int
        private let _startShiftedX: Int
        private let _startShiftedY: Int
        private let _startCell: Cell?

        init(_ cellGridView: CellGridView, _ viewPoint: CGPoint, picker: Bool = false) {
            self._cellGridView = cellGridView
            self._startX = Int(round(viewPoint.x))
            self._startY = Int(round(viewPoint.y))
            self._startShiftedX = cellGridView.shiftTotalX
            self._startShiftedY = cellGridView.shiftTotalY
            self._startCell = picker ? cellGridView.gridCell(viewPoint: viewPoint) : nil
        }

        public func drag(_ viewPoint: CGPoint, end: Bool = false) {
            if let startCell: Cell = self._startCell,
               let cell: Cell = self._cellGridView.gridCell(viewPoint: viewPoint) {
                cell.select(dragging: true)
                return
            }
            let dragPoint: ViewPoint = ViewPoint(viewPoint)
            let dragX: Int = dragPoint.x
            let dragY: Int = dragPoint.y
            let dragDeltaX = self._startX - dragX
            let dragDeltaY = self._startY - dragY
            let shiftX =  self._startShiftedX - dragDeltaX
            let shiftY = self._startShiftedY - dragDeltaY
            self._cellGridView.writeCells(shiftTotalX: shiftX, shiftTotalY: shiftY, dragging: !end)
        }

        public func end(_ viewPoint: CGPoint) {
            self.drag(viewPoint, end: true)
        }
    }
}
