import Foundation

// Represents an integer based cell-based (i.e. cell-indexed) location within the cell-grid.
// Exactly the same as ViewPoint but differential naming has documentation value.
//
struct CellLocation: Equatable, CustomStringConvertible
{
    public let x: Int
    public let y: Int

    init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    init(_ point: CGPoint) {
        self.x = Int(round(point.x))
        self.y = Int(round(point.y))
    }

    init(_ x: CGFloat, _ y: CGFloat) {
        self.x = Int(round(x))
        self.y = Int(round(y))
    }

    public var description: String {
        String(format: "[%d, %d]", self.x, self.y)
    }
}
