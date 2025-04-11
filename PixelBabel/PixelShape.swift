import SwiftUI

enum PixelShape: String, CaseIterable, Identifiable {
    case square = "Square"
    case inset = "Inset"
    case rounded = "Rounded"
    case circle = "Circle"
    var id: String { self.rawValue }
}
