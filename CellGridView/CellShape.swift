public enum CellShape: String, CaseIterable, Identifiable, Sendable
{
    case square  = "Square"
    case inset   = "Inset"
    case rounded = "Rounded"
    case circle  = "Circle"
    public var id: String { self.rawValue }
}
