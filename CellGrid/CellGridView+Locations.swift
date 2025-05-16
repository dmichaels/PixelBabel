import Foundation
import Utils

extension CellGridView
{
    // Returns the cell-grid cell object for the given grid-view input location, or nil;
    // note that the display input location is always in unscaled units.
    //
    public func gridCell<T: Cell>(_ viewPoint: CGPoint) -> T? {
        if let gridPoint: CellLocation = self.gridCellLocation(viewPoint) {
            return self.gridCell(gridPoint.x, gridPoint.y)
        }
        return nil
    }

    // Returns the cell-grid cell object for the given cell-grid cell location, or nil.
    //
    public func gridCell<T: Cell>(_ gridCellX: Int, _ gridCellY: Int) -> T? {
        guard gridCellX >= 0, gridCellX < self.gridColumns, gridCellY >= 0, gridCellY < self.gridRows else {
            return nil
        }
        return self.gridCells[gridCellY * self.gridColumns + gridCellX] as? T
    }

    // Returns the cell-grid cell location of the given grid-view input point, or nil;
    // note that the display input location is always in unscaled units.
    //
    public func gridCellLocation(_ viewPoint: CGPoint) -> CellLocation? {
        return self.gridCellLocation(viewPoint.x, viewPoint.y)
    }

    public func gridCellLocation(_ viewPointX: CGFloat, _ viewPointY: CGFloat) -> CellLocation? {

        if let viewCellLocation: CellLocation = self.viewCellLocation(viewPointX, viewPointY) {
            let shiftX: Int = self.shiftX
            let shiftY: Int = self.shiftY
            let gridCellX: Int = viewCellLocation.x - self.shiftCellX - ((shiftX > 0) ? 1 : 0)
            guard gridCellX >= 0, gridCellX < self.gridColumns else { return nil }
            let gridCellY: Int = viewCellLocation.y - self.shiftCellY - ((shiftY > 0) ? 1 : 0)
            guard gridCellY >= 0, gridCellY < self.gridRows else { return nil }
            return CellLocation(gridCellX, gridCellY)
        }
        return nil
    }

    public func viewCellFromGridCellLocation(_ gridCellX: Int, _ gridCellY: Int) -> CellLocation? {
        let shiftX: Int = self.shiftX
        let shiftY: Int = self.shiftY
        let viewCellX: Int = gridCellX + self.shiftCellX + ((shiftX > 0) ? 1 : 0)
        let viewCellY: Int = gridCellY + self.shiftCellY + ((shiftY > 0) ? 1 : 0)
        return CellLocation(viewCellX, viewCellY)
    }

    // Returns the cell location relative to the grid-view of the given grid-view input point, or nil.
    //
    public func viewCellLocation(_ viewPoint: CGPoint) -> CellLocation? {
        return self.viewCellLocation(viewPoint.x, viewPoint.y)
    }

    public func viewCellLocation(_ viewPointX: CGFloat, _ viewPointY: CGFloat) -> CellLocation? {
        guard viewPointX >= 0.0, viewPointX < CGFloat(self.viewWidth),
              viewPointY >= 0.0, viewPointY < CGFloat(self.viewHeight) else { return nil }
        let shiftX: Int = self.shiftX
        let shiftY: Int = self.shiftY
        let viewCellX: Int = ((shiftX > 0) ? (Int(floor(viewPointX)) + (self.cellSize - shiftX))
                                           : (Int(floor(viewPointX)) - shiftX)) / self.cellSize
        let viewCellY: Int = ((shiftY > 0) ? (Int(floor(viewPointY)) + (self.cellSize - shiftY))
                                           : (Int(floor(viewPointY)) - shiftY)) / self.cellSize
        return CellLocation(viewCellX, viewCellY)
    }

    // Normalizes an input point taking into account orientation et cetera.
    //
    public func normalizedPoint(screenPoint: CGPoint,
                                viewOrigin viewOrigin: CGPoint,
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
