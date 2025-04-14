import SwiftUI
import Foundation

class FixedSettings {
    public static let pixelMarginMax: Int = 6
    public static let pixelSizeMarginMin: Int = 4
}

class DefaultSettings
{
    public static let pixelSize: Int = 10
    public static let colorMode: ColorMode = ColorMode.color
    public static let rgbFilter: RGBFilterOptions = RGBFilterOptions.RGB
    public static let pixelShape: PixelShape = PixelShape.square
    public static let pixelMargin: Int = 2
    public static let backgroundBufferSizeDefault: Int = 50
    public static let backgroundBufferSizeMax: Int = 250
    public static let updateMode: Bool = false
    public static let writeAlgorithm: WriteAlgorithm = WriteAlgorithm.auto
    public static let screenSmall: Bool = false
}

enum WriteAlgorithm: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case new = "New"
    case best = "Best"
    case experimental = "Experimental"
    case legacy = "Legacy"
    var id: String { self.rawValue }
}

class Settings: ObservableObject
{
    @Published var pixels: PixelMap
    @Published var pixelSize: Int = DefaultSettings.pixelSize
    @Published var colorMode: ColorMode = DefaultSettings.colorMode
    @Published var rgbFilter: RGBFilterOptions = DefaultSettings.rgbFilter
    @Published var pixelShape: PixelShape = DefaultSettings.pixelShape
    @Published var pixelMargin: Int = DefaultSettings.pixelMargin
    @Published var backgroundColor: Pixel = Pixel.dark
    @Published var updateMode: Bool = DefaultSettings.updateMode
    @Published var writeAlgorithm: WriteAlgorithm = DefaultSettings.writeAlgorithm
    @Published var soundEnabled: Bool = true
    @Published var hapticEnabled: Bool = true
    @Published var randomFixedImage: Bool = false
    @Published var randomFixedImagePeriod: RandomFixedImagePeriod = RandomFixedImagePeriod.sometimes
    @Published var backgroundBufferEnabled: Bool = true
    @Published var backgroundBufferSize: Int = DefaultSettings.backgroundBufferSizeDefault
    @Published var automationEnabled: Bool = true
    @Published var automationSpeed: Double = 0.1
    @Published var dummy: Date = Date()
    @Published var screenSmall: Bool = DefaultSettings.screenSmall

    init() {
        self.pixels = PixelMap(ScreenWidth, ScreenHeight,
                               scale: DefaultSettings.pixelSize,
                               mode: DefaultSettings.colorMode,
                               filter: DefaultSettings.rgbFilter,
                               backgroundBufferSize: DefaultSettings.backgroundBufferSizeDefault,
                               writeAlgorithm: DefaultSettings.writeAlgorithm)
    }
}
