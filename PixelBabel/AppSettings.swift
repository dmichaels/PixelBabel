import SwiftUI
import Foundation

class FixedAppSettings {
    public static let pixelMarginMax: Int = 6
    public static let pixelSizeMarginMin: Int = 4
}

class DefaultAppSettings
{
    public static let pixelSize: Int = 10
    public static let colorMode: ColorMode = ColorMode.color
    public static let rgbFilter: RGBFilterOptions = RGBFilterOptions.RGB
    public static let pixelShape: PixelShape = PixelShape.square
    public static let pixelMargin: Int = 1
    public static let backgroundBufferSizeDefault: Int = 50
    public static let backgroundBufferSizeMax: Int = 250
}

class AppSettings: ObservableObject
{
    @Published var pixels: PixelMap
    @Published var pixelSize: Int = DefaultAppSettings.pixelSize
    @Published var colorMode: ColorMode = DefaultAppSettings.colorMode
    @Published var rgbFilter: RGBFilterOptions = DefaultAppSettings.rgbFilter
    @Published var pixelShape: PixelShape = DefaultAppSettings.pixelShape
    @Published var pixelMargin: Int = DefaultAppSettings.pixelMargin
    @Published var backgroundColor: Pixel = Pixel.dark
    @Published var soundEnabled: Bool = true
    @Published var hapticEnabled: Bool = true
    @Published var randomFixedImage: Bool = false
    @Published var randomFixedImagePeriod: RandomFixedImagePeriod = RandomFixedImagePeriod.sometimes
    @Published var backgroundBufferEnabled: Bool = true
    @Published var backgroundBufferSize: Int = DefaultAppSettings.backgroundBufferSizeDefault
    @Published var automationEnabled: Bool = true
    @Published var automationSpeed: Double = 0.1
    @Published var dummy: Date = Date()

    init() {
        self.pixels = PixelMap(ScreenWidth, ScreenHeight,
                               scale: DefaultAppSettings.pixelSize,
                               mode: DefaultAppSettings.colorMode,
                               filter: DefaultAppSettings.rgbFilter,
                               backgroundBufferSize: DefaultAppSettings.backgroundBufferSizeDefault)
    }
}
