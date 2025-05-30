import CoreGraphics
import SwiftUI

extension CGPoint: CustomStringConvertible {
    public var description: String {
        String(format: "[%.1f, %.1f]", self.x, self.y)
    }
}
