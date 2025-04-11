import SwiftUI

// This is actually only currently used for the background color of the screen/image,
// i.e. for the backgound color if the inset margin is greater than zero.
//
struct Pixel: Equatable {

    var _value: UInt32

    public static let black: Pixel = Pixel(0, 0, 0)
    public static let white: Pixel = Pixel(255, 255, 255)
    public static let dark: Pixel = Pixel(50, 50, 50)
    public static let light: Pixel = Pixel(200, 200, 200)

    public var red: UInt8 {
        get { UInt8((self._value >> 24) & 0xFF) }
    }

    public var green: UInt8 {
        get { UInt8((self._value >> 16) & 0xFF) }
    }

    public var blue: UInt8 {
        get { UInt8((self._value >> 8) & 0xFF) }
    }

    public var transparency: UInt8 {
        get { UInt8(self._value & 0xFF) }
    }

    init(_ red: UInt8, _ green: UInt8, _ blue: UInt8, transparency: UInt8 = 255) {
        self._value = (UInt32(red) << 24) | (UInt32(green) << 16) | (UInt32(blue) << 8) | UInt32(transparency)
    }

    public var color: Color {
        get { return Color(red: Double(self.red) / 255.0, green: Double(self.green) / 255.0, blue: Double(self.blue) / 255.0) }
    }

    public static func random(mode: ColorMode = ColorMode.color, filter: RGBFilterOptions? = nil) -> Pixel {
        if (mode == ColorMode.monochrome) {
            let value: UInt8 = UInt8.random(in: 0...1) * 255
            return Pixel(value, value, value)
        }
        else if (mode == ColorMode.grayscale) {
            let value = UInt8.random(in: 0...255)
            return Pixel(value, value, value)
        }
        else {
            var rgb = UInt32.random(in: 0...0xFFFFFF)
            if (filter != RGBFilterOptions.RGB) {
                rgb = filter!.function(rgb)
            }
            return Pixel(UInt8((rgb >> 16) & 0xFF), UInt8((rgb >> 8) & 0xFF), UInt8(rgb & 0xFF))
        }
    }
}
