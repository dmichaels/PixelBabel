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

        init(_ cellGridView: CellGridView, _ screenPoint: CGPoint) {
            self.cellGridView = cellGridView
            self.startX = Int(round(screenPoint.x))
            self.startY = Int(round(screenPoint.y))
            let startShifted: CellLocation = cellGridView.shifted
            self.startShiftedX = startShifted.x
            self.startShiftedY = startShifted.y
        }

        public func drag(_ screenPoint: CGPoint) {
            let dragX: Int = Int(round(screenPoint.x))
            let dragY: Int = Int(round(screenPoint.y))
            let dragDeltaX = self.startX - dragX
            let dragDeltaY = self.startY - dragY
            let shiftX =  self.startShiftedX - dragDeltaX
            let shiftY = self.startShiftedY - dragDeltaY
            self.cellGridView.shift(shiftx: shiftX, shifty: shiftY)
        }

        public func end(_ screenPoint: CGPoint) {
            self.drag(screenPoint)
        }
    }
}
