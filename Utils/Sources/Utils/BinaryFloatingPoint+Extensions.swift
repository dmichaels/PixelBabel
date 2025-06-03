import Foundation

extension BinaryFloatingPoint {
    func rounded(_ places: Int) -> Self {
        guard places >= 0 else { return self }
        let multiplier = Self(pow(10.0, Double(places)))
        return (self * multiplier).rounded() / multiplier
    }
}
