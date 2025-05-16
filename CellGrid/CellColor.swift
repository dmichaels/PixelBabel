import SwiftUI

// This is actually only currently used for the background color of the screen/image,
// i.e. for the backgound color if the inset margin is greater than zero.
//
struct CellColor: Equatable
{
    // These values works with Memory.fastcopy NOT using value.bigEndian;
    // if these were the opposite (i.e. red-24, green-16, blue-8, alpha-0)
    // then we would need to use value.bigEndian there; slightly faster without.
    //
    public static let RSHIFT: Int   =   0
    public static let GSHIFT: Int   =   8
    public static let BSHIFT: Int   =  16
    public static let ASHIFT: Int   =  24
    public static let OPAQUE: UInt8 = 255

    var _red:   UInt8
    var _green: UInt8
    var _blue:  UInt8
    var _alpha: UInt8 = 255

    public var red:   UInt8 { self._red   }
    public var green: UInt8 { self._green }
    public var blue:  UInt8 { self._blue  }
    public var alpha: UInt8 { self._alpha }

    public var value: UInt32 {
        get {
            (UInt32(self._red)   << CellColor.RSHIFT) |
            (UInt32(self._green) << CellColor.GSHIFT) |
            (UInt32(self._blue)  << CellColor.BSHIFT) |
            (UInt32(self._alpha) << CellColor.ASHIFT)
        }
    }

    public var hex: String {
        String(format: "%02X", self.value)
    }

    init(_ red: UInt8, _ green: UInt8, _ blue: UInt8, alpha: UInt8 = 255) {
        self._red   = red
        self._green = green
        self._blue  = blue
        self._alpha = alpha
    }

    init(_ red: Int, _ green: Int, _ blue: Int, alpha: Int = 255) {
        self._red   = UInt8(red)
        self._green = UInt8(green)
        self._blue  = UInt8(blue)
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
        var red:   CGFloat = 0
        var green: CGFloat = 0
        var blue:  CGFloat = 0
        var alpha: CGFloat = 0
        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self._red   = UInt8(red   * 255)
            self._green = UInt8(green * 255)
            self._blue  = UInt8(blue  * 255)
            self._alpha = UInt8(alpha * 255)
        }
        else {
            self._red   = 0
            self._green = 0
            self._blue  = 0
        }
    }

    init(_ value: UInt32) {
        self._red   = UInt8((value >> CellColor.RSHIFT) & 0xFF)
        self._green = UInt8((value >> CellColor.GSHIFT) & 0xFF)
        self._blue  = UInt8((value >> CellColor.BSHIFT) & 0xFF)
        self._alpha = UInt8((value >> CellColor.ASHIFT) & 0xFF)
    }

    public var color: Color {
        Color(red: Double(self.red) / 255.0, green: Double(self.green) / 255.0, blue: Double(self.blue) / 255.0)
    }

    public static let black: CellColor = CellColor(0, 0, 0)
    public static let white: CellColor = CellColor(255, 255, 255)
    public static let dark:  CellColor = CellColor(50, 50, 50)
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
}
