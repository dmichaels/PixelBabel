import Foundation
import Utils

extension CellGridView
{
    private func scaled(_ viewPoint: CGFloat) -> CGFloat {
        return Screen.shared.scaled(viewPoint, scaling: self.viewScaling)
    }

    // Returns the cell-grid cell object for the given cell-grid cell location, or nil.
    //
    public func gridCell<T: Cell>(_ gridCellX: Int, _ gridCellY: Int) -> T? {
        guard gridCellX >= 0, gridCellX < self.gridColumns, gridCellY >= 0, gridCellY < self.gridRows else {
            return nil
        }
        return self.gridCells[gridCellY * self.gridColumns + gridCellX] as? T
    }

    // Returns the cell-grid cell object for the given grid-view input location, or nil;
    // note that the display input location is always in unscaled units.
    //
    public func gridCell<T: Cell>(viewPoint: CGPoint) -> T? {
        if let gridCellLocation: CellLocation = self.gridCellLocation(viewPoint: viewPoint) {
            return self.gridCell(gridCellLocation.x, gridCellLocation.y)
        }
        return nil
    }

    // Returns the cell-grid cell object for the given grid-view cell location, or nil.
    //
    public func gridCell<T: Cell>(viewCellX: Int, viewCellY: Int) -> T? {
        if let gridCellLocation: CellLocation = self.gridCellLocation(viewCellX: viewCellX, viewCellY: viewCellY) {
            return self.gridCells[gridCellLocation.y * self.gridColumns + gridCellLocation.x] as? T
        }
        return nil
    }

    // Returns the cell-grid cell location of the given grid-view input point, or nil;
    // note that the view input point is always in unscaled units.
    //
    public func gridCellLocation(viewPoint: CGPoint) -> CellLocation? {
        if let viewCellLocation: CellLocation = self.viewCellLocation(viewPoint: viewPoint) {
            let gridCellX: Int = viewCellLocation.x - self.shiftCellX - ((self.shiftScaledX > 0) ? 1 : 0)
            guard gridCellX >= 0, gridCellX < self.gridColumns else { return nil }
            let gridCellY: Int = viewCellLocation.y - self.shiftCellY - ((self.shiftScaledY > 0) ? 1 : 0)
            guard gridCellY >= 0, gridCellY < self.gridRows else { return nil }
            return CellLocation(gridCellX, gridCellY)
        }
        return nil
    }

    // Returns the cell-grid cell location of the given grid-view cell location.
    //
    public func gridCellLocation(viewCellX: Int, viewCellY: Int) -> CellLocation? {
        guard viewCellX >= 0, viewCellX <= self.viewCellEndX,
              viewCellY >= 0, viewCellY <= self.viewCellEndY else { return nil }
        let gridCellX: Int = viewCellX - self.shiftCellX - ((self.shiftScaledX > 0) ? 1 : 0)
        let gridCellY: Int = viewCellY - self.shiftCellY - ((self.shiftScaledY > 0) ? 1 : 0)
        guard gridCellX >= 0, gridCellX < self.gridColumns,
              gridCellY >= 0, gridCellY < self.gridRows else { return nil }
        return CellLocation(gridCellX, gridCellY)
    }

    // Returns the cell location relative to the grid-view of the given grid-view input point, or nil.
    //
    public func viewCellLocation(viewPoint: CGPoint) -> CellLocation? {
        let viewPointX: CGFloat = self.scaled(viewPoint.x)
        let viewPointY: CGFloat = self.scaled(viewPoint.y)
        guard viewPointX >= 0.0, viewPointX < CGFloat(self.viewWidthScaled),
              viewPointY >= 0.0, viewPointY < CGFloat(self.viewHeightScaled) else { return nil }
        let viewCellX: Int = ((self.shiftScaledX > 0) ? (Int(floor(viewPointX)) + (self.cellSizeScaled - self.shiftScaledX))
                                           : (Int(floor(viewPointX)) - self.shiftScaledX)) / self.cellSizeScaled
        let viewCellY: Int = ((self.shiftScaledY > 0) ? (Int(floor(viewPointY)) + (self.cellSizeScaled - self.shiftScaledY))
                                           : (Int(floor(viewPointY)) - self.shiftScaledY)) / self.cellSizeScaled
        return CellLocation(viewCellX, viewCellY)
    }

    // Returns the grid-view cell location of the given cell-grid cell location, or nil.
    //
    public func viewCellLocation(gridCellX: Int, gridCellY: Int) -> CellLocation? {
        guard gridCellX >= 0, gridCellX < self.gridColumns,
              gridCellY >= 0, gridCellY < self.gridRows else { return nil }
        let viewCellX: Int = gridCellX + self.shiftCellX + ((self.shiftScaledX > 0) ? 1 : 0)
        let viewCellY: Int = gridCellY + self.shiftCellY + ((self.shiftScaledY > 0) ? 1 : 0)
        guard viewCellX >= 0, viewCellX <= self.viewCellEndX,
              viewCellY >= 0, viewCellY <= self.viewCellEndY else { return nil }
        return CellLocation(viewCellX, viewCellY)
    }

    // Normalizes an input point taking into account orientation et cetera.
    // The input screen point is (as always) unscaled as well as the returned point.
    //
    public func normalizedPoint(screenPoint: CGPoint,
                                viewOrigin: CGPoint,
                                orientation: OrientationObserver) -> CGPoint
    {
        // Various oddities with upside-down mode and having to know the
        // previous orientation and whether or not we are an iPad and whatnot.
        //
        let x, y: CGFloat
        switch orientation.current {
        case .portrait:
            x = screenPoint.x - viewOrigin.x
            y = screenPoint.y - viewOrigin.y
        case .portraitUpsideDown:
            if (orientation.ipad) {
                x = CGFloat(self.viewWidth) - 1 - (screenPoint.x - viewOrigin.x)
                y = CGFloat(self.viewHeight) - 1 - (screenPoint.y - viewOrigin.y)
            }
            else if (orientation.previous.isLandscape) {
                x = screenPoint.y - viewOrigin.x
                y = CGFloat(self.viewHeight) - 1 - (screenPoint.x - viewOrigin.y)
            }
            else {
                x = screenPoint.x - viewOrigin.x
                y = screenPoint.y - viewOrigin.y
            }
        case .landscapeRight:
            x = screenPoint.y - viewOrigin.x
            y = CGFloat(self.viewHeight) - 1 - (screenPoint.x - viewOrigin.y)
        case .landscapeLeft:
            x = CGFloat(self.viewWidth) - 1 - (screenPoint.y - viewOrigin.x)
            y = screenPoint.x - viewOrigin.y
        default:
            x = screenPoint.x - viewOrigin.x
            y = screenPoint.y - viewOrigin.y
        }
        return CGPoint(x: x, y: y)
    }
}
