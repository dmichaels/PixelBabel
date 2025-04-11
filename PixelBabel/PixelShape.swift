import SwiftUI

enum PixelShape: String, CaseIterable, Identifiable {
    case square = "Square"
    case circle = "Circle"
    var id: String { self.rawValue }
}
