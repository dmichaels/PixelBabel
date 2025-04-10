import SwiftUI

struct RGBFilters {

    static func RGB(pixel: UInt32) -> UInt32 { return pixel }
    static func RGx(pixel: UInt32) -> UInt32 { return pixel | 0x0000FF }
    static func RGo(pixel: UInt32) -> UInt32 { return pixel & 0xFFFF00 }
    static func RxB(pixel: UInt32) -> UInt32 { return pixel | 0x00FF00 }
    static func Rxx(pixel: UInt32) -> UInt32 { return pixel | 0x00FFFF }
    static func Rxo(pixel: UInt32) -> UInt32 { return (pixel | 0x00FF00) & 0xFFFF00 }
    static func RoB(pixel: UInt32) -> UInt32 { return pixel & 0xFF00FF }
    static func Rox(pixel: UInt32) -> UInt32 { return (pixel & 0xFF00FF) & 0x0000FF }
    static func Roo(pixel: UInt32) -> UInt32 { return pixel & 0xFF0000 }
    static func xGB(pixel: UInt32) -> UInt32 { return pixel | 0xFF0000 }
    static func xGx(pixel: UInt32) -> UInt32 { return pixel | 0xFF00FF }
    static func xGo(pixel: UInt32) -> UInt32 { return (pixel | 0xFF0000) & 0xFFFF00 }
    static func xxB(pixel: UInt32) -> UInt32 { return pixel | 0xFFFF00 }
    static func xxx(pixel: UInt32) -> UInt32 { return pixel | 0xFFFFFF }
    static func xxo(pixel: UInt32) -> UInt32 { return (pixel | 0xFFFF00) & 0xFFFF00 }
    static func xoB(pixel: UInt32) -> UInt32 { return (pixel | 0xFF0000) & 0xFF00FF }
    static func xox(pixel: UInt32) -> UInt32 { return (pixel | 0xFF00FF) & 0xFF00FF }
    static func xoo(pixel: UInt32) -> UInt32 { return (pixel | 0xFF0000) & 0xFF0000 }
    static func oGB(pixel: UInt32) -> UInt32 { return pixel & 0x00FFFF }
    static func oGx(pixel: UInt32) -> UInt32 { return (pixel & 0x00FFFF) | 0x0000FF }
    static func oGo(pixel: UInt32) -> UInt32 { return pixel & 0x00FF00 }
    static func oxB(pixel: UInt32) -> UInt32 { return (pixel & 0x00FFFF) | 0x00FF00 }
    static func oxx(pixel: UInt32) -> UInt32 { return (pixel & 0x00FFFF) | 0x00FFFF }
    static func oxo(pixel: UInt32) -> UInt32 { return (pixel & 0x00FF00) | 0x00FF00 }
    static func ooB(pixel: UInt32) -> UInt32 { return pixel & 0x0000FF }
    static func oox(pixel: UInt32) -> UInt32 { return (pixel & 0x0000FF) | 0x0000FF }
    static func ooo(pixel: UInt32) -> UInt32 { return pixel & 0x000000 }
}

enum RGBFilterOptions: String, CaseIterable, Identifiable {

    var id: String { self.rawValue }

    case
        RGB, // RGB
        Roo, // Reds
        xGB, // Red-ish
        oGB, // Red-less
        oGo, // Greens
        RxB, // Green-ish
        RoB, // Green-less
        ooB, // Blues
        RGx, // Blue-ish
        RGo  // Blue-less
     // Rxx,
     // Rxo,
     // Rox,
     // xGx,
     // xGo,
     // xxB,
     // xxx, // White
     // xxo, // Yellow
     // xoB,
     // xox, // Magenta
     // xoo, // Red
     // oGx,
     // oxB,
     // oxx, // Cyan
     // oxo, // Green
     // oox, // Blue
     // ooo  // Black

    var label: String {
        switch self {
        case .RGB: return "RGB"
        case .Roo: return "Reds"
        case .xGB: return "Red-ish"
        case .oGB: return "Red-less"
        case .oGo: return "Greens"
        case .RxB: return "Green-ish"
        case .RoB: return "Green-less"
        case .ooB: return "Blues"
        case .RGx: return "Blue-ish"
        case .RGo: return "Blue-less"
        }
    }

    public static var foo: Int = 0

    var function: (UInt32) -> UInt32 {
        switch self {
        case .RGB: return RGBFilters.RGB
        case .RGx: return RGBFilters.RGx
        case .RGo: return RGBFilters.RGo
        case .RxB: return RGBFilters.RxB
     // case .Rxx: return RGBFilters.Rxx
     // case .Rxo: return RGBFilters.Rxo
        case .RoB: return RGBFilters.RoB
     // case .Rox: return RGBFilters.Rox
        case .Roo: return RGBFilters.Roo
        case .xGB: return RGBFilters.xGB
     // case .xGx: return RGBFilters.xGx
     // case .xGo: return RGBFilters.xGo
     // case .xxB: return RGBFilters.xxB
     // case .xxx: return RGBFilters.xxx
     // case .xxo: return RGBFilters.xxo
     // case .xoB: return RGBFilters.xoB
     // case .xox: return RGBFilters.xox
     // case .xoo: return RGBFilters.xoo
        case .oGB: return RGBFilters.oGB
     // case .oGx: return RGBFilters.oGx
        case .oGo: return RGBFilters.oGo
     // case .oxB: return RGBFilters.oxB
     // case .oxx: return RGBFilters.oxx
     // case .oxo: return RGBFilters.oxo
        case .ooB: return RGBFilters.ooB
     // case .oox: return RGBFilters.oox
     // case .ooo: return RGBFilters.ooo
        }
    }
}
