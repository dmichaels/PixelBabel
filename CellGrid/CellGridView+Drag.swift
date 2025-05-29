import Foundation
import Utils

extension CellGridView
{
    @MainActor
    public struct Drag
    {
        public let cellGridView: CellGridView
        public let startX: Int
        public let startY: Int
        public let startShiftedX: Int
        public let startShiftedY: Int

        init(_ cellGridView: CellGridView, _ viewPoint: CGPoint) {
            self.cellGridView = cellGridView
            self.startX = Int(round(viewPoint.x))
            self.startY = Int(round(viewPoint.y))
            let startShifted: CellLocation = cellGridView.shifted
            self.startShiftedX = startShifted.x
            self.startShiftedY = startShifted.y
        }

        public func drag(_ viewPoint: CGPoint) {
            let dragX: Int = Int(round(viewPoint.x))
            let dragY: Int = Int(round(viewPoint.y))
            let dragDeltaX = self.startX - dragX
            let dragDeltaY = self.startY - dragY
            let shiftX =  self.startShiftedX - dragDeltaX
            let shiftY = self.startShiftedY - dragDeltaY
            self.cellGridView.shift(shiftx: shiftX, shifty: shiftY)
        }

        public func end(_ viewPoint: CGPoint) {
            self.drag(viewPoint)
        }
    }
}
