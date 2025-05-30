import Foundation

enum CellColorMode: String, CaseIterable, Identifiable
{
    case monochrome = "Monochrome"
    case grayscale  = "Grayscale"
    case color      = "Color"
    var id: String { self.rawValue }
}
