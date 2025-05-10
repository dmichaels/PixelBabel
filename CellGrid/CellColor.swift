import SwiftUI

// This is actually only currently used for the background color of the screen/image,
// i.e. for the backgound color if the inset margin is greater than zero.
//
struct CellColor: Equatable {

    public static var _debugInitCount: Int = 0

    var _red: UInt8
    var _green: UInt8
    var _blue: UInt8
    var _alpha: UInt8 = 255

    public var red: UInt8 {
        get { self._red }
    }

    public var green: UInt8 {
        get { self._green }
    }

    public var blue: UInt8 {
        get { self._blue }
    }

    public var alpha: UInt8 {
        get { self._alpha }
    }

    public var value: UInt32 {
        get {
            (UInt32(self._red)   << 24) |
            (UInt32(self._green) << 16) |
            (UInt32(self._blue)  << 8)  |
            (UInt32(self._alpha))
        }
    }

    public var hex: String {
        String(format: "%02X", self.value)
    }

    init(_ red: UInt8, _ green: UInt8, _ blue: UInt8, alpha: UInt8 = 255) {
        // CellColor._debugInitCount += 1
        self._red = red
        self._green = green
        self._blue = blue
        self._alpha = alpha
    }

    init(_ red: Int, _ green: Int, _ blue: Int, alpha: Int = 255) {
        // CellColor._debugInitCount += 1
        self._red = UInt8(red)
        self._green = UInt8(green)
        self._blue = UInt8(blue)
        self._alpha = UInt8(alpha)
    }

    // N.B. Creating UIColor many times an be sloooooooooooooow. 
    // For example doing this 1200 * 2100 = 2,520,000 times can take
    // nearly 2 full seconds. Be careful to avoid this if/when possible.
    //
    init(_ color: Color) {
        self.init(UIColor(color))
    }

    init(_ color: UIColor) {
        CellColor._debugInitCount += 1
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self._red = UInt8(red * 255)
            self._green = UInt8(green * 255)
            self._blue = UInt8(blue * 255)
            self._alpha = UInt8(alpha * 255)
        }
        else {
            self._red = 0
            self._green = 0
            self._blue = 0
        }
    }

    init(_ value: UInt32) {
        // CellColor._debugInitCount += 1
        self._red = UInt8((value >> 24) & 0xFF)
        self._green = UInt8((value >> 16) & 0xFF)
        self._blue = UInt8((value >> 8) & 0xFF)
        self._alpha = UInt8(value & 0xFF)
    }

    public var color: Color {
        get { return Color(red: Double(self.red) / 255.0, green: Double(self.green) / 255.0, blue: Double(self.blue) / 255.0) }
    }

    public static func valueOf(_ red: UInt8, _ green: UInt8, _ blue: UInt8, alpha: UInt8 = 255) -> UInt32 {
        return (UInt32(red)   << 24) |
               (UInt32(green) << 16) |
               (UInt32(blue)  << 8)  |
               (UInt32(alpha))
    }

    public static let black: CellColor = CellColor(0, 0, 0)
    public static let white: CellColor = CellColor(255, 255, 255)
    public static let dark: CellColor = CellColor(50, 50, 50)
    public static let light: CellColor = CellColor(200, 200, 200)

    public static func random(mode: CellColorMode = CellColorMode.color) -> CellColor {
        if (mode == CellColorMode.monochrome) {
            let value: UInt8 = UInt8.random(in: 0...1) * 255
            return CellColor(value, value, value)
        }
        else if (mode == CellColorMode.grayscale) {
            let value = UInt8.random(in: 0...255)
            return CellColor(value, value, value)
        }
        else {
            let rgb = UInt32.random(in: 0...0xFFFFFF)
            return CellColor(UInt8((rgb >> 16) & 0xFF), UInt8((rgb >> 8) & 0xFF), UInt8(rgb & 0xFF))
        }
    }

    typealias FilterFunction = (inout [UInt8], Int) -> Void

    public func tintedRed(by amount: CGFloat) -> CellColor {
        let clampedAmount = min(max(amount, 0), 1)
        let newRed = UInt8(clampedAmount * 255 + (1 - clampedAmount) * CGFloat(self.red))
        let newGreen = UInt8((1 - clampedAmount) * CGFloat(self.green))
        let newBlue = UInt8((1 - clampedAmount) * CGFloat(self.blue))
        return CellColor(newRed, newGreen, newBlue, alpha: self.alpha)
    }

    public static let null: CellColor = CellColor(0, 0, 0, alpha: 0)
}
