import SwiftUI

extension Cells {

    func lifeCell(_ screenPoint: CGPoint) -> LifeCell? {
        guard let cell = self.cell(screenPoint) as? LifeCell else {
            return nil
        }
        return cell
    }

    func lifeCell(_ x: Int, _ y: Int) -> LifeCell? {
        guard let cell = self.cell(x, y) as? LifeCell else {
            return nil
        }
        return cell
    }
}
