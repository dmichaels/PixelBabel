import Foundation

struct CellGridPoint: Equatable {

    public let x: Int
    public let y: Int

    init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    init(_ point: CGPoint) {
        // self.x = Int(round(point.x))
        // self.y = Int(round(point.y))
        self.x = Int(floor(point.x))
        self.y = Int(floor(point.y))
    }
}
