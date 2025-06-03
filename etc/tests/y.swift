import Foundation

extension BinaryFloatingPoint {
    func rounded(_ places: Int) -> Self {
        guard places >= 0 else { return self }
        let multiplier = Self(pow(10.0, Double(places)))
        return (self * multiplier).rounded() / multiplier
    }
}

let cellSize: Int = 5
let cellCenter: Double = 2.4
let cellIndex: Int = Int(cellCenter)
let cellIndexOffset: Double = (cellCenter - Double(cellIndex)) * Double(cellSize)
let cellIndexOffsetRounded: Double = cellIndexOffset.rounded(3)
print(cellIndexOffsetRounded)  // 2.0
