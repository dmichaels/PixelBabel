import Foundation

public enum CellColorMode: String, CaseIterable, Identifiable
{
    case monochrome = "Monochrome"
    case grayscale  = "Grayscale"
    case color      = "Color"
    public var id: String { self.rawValue }
}
