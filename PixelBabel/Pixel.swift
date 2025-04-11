// This is actually only currently used for the background color of the screen/image,
// i.e. for the backgound color if the inset margin is greater than zero.
//
struct Pixel {

    var _value: UInt32

    var red: UInt8 {
        get { UInt8((self._value >> 24) & 0xFF) }
        set { self._value = (self._value & 0x00FFFFFF) | (UInt32(newValue) << 24) }
    }

    var green: UInt8 {
        get { UInt8((self._value >> 16) & 0xFF) }
        set { self._value = (self._value & 0xFF00FFFF) | (UInt32(newValue) << 16) }
    }

    var blue: UInt8 {
        get { UInt8((self._value >> 8) & 0xFF) }
        set { self._value = (self._value & 0xFFFF00FF) | (UInt32(newValue) << 8) }
    }

    var transparency: UInt8 {
        get { UInt8(self._value & 0xFF) }
        set { self._value = (self._value & 0xFFFFFF00) | UInt32(newValue) }
    }

    init(_ red: UInt8, _ green: UInt8, _ blue: UInt8, transparency: UInt8 = 255) {
        self._value = (UInt32(red) << 24) | (UInt32(green) << 16) | (UInt32(blue) << 8) | UInt32(transparency)
    }

    public static let black: Pixel = Pixel(0, 0, 0)
    public static let white: Pixel = Pixel(255, 255, 255)
    public static let dark: Pixel = Pixel(50, 50, 50)
    public static let light: Pixel = Pixel(200, 200, 200)
}
