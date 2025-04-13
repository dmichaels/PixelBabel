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
    public static let pixelMargin: Int = 1
    public static let backgroundBufferSizeDefault: Int = 50
    public static let backgroundBufferSizeMax: Int = 250
    public static let updateMode: Bool = false
    public static let writeAlgorithmLegacy: Bool = false
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
    @Published var writeAlgorithmLegacy: Bool = DefaultSettings.writeAlgorithmLegacy
    @Published var soundEnabled: Bool = true
    @Published var hapticEnabled: Bool = true
    @Published var randomFixedImage: Bool = false
    @Published var randomFixedImagePeriod: RandomFixedImagePeriod = RandomFixedImagePeriod.sometimes
    @Published var backgroundBufferEnabled: Bool = true
    @Published var backgroundBufferSize: Int = DefaultSettings.backgroundBufferSizeDefault
    @Published var automationEnabled: Bool = true
    @Published var automationSpeed: Double = 0.1
    @Published var dummy: Date = Date()

    init() {
        self.pixels = PixelMap(ScreenWidth, ScreenHeight,
                               scale: DefaultSettings.pixelSize,
                               mode: DefaultSettings.colorMode,
                               filter: DefaultSettings.rgbFilter,
                               backgroundBufferSize: DefaultSettings.backgroundBufferSizeDefault,
                               writeAlgorithmLegacy: DefaultSettings.writeAlgorithmLegacy)
    }
}
