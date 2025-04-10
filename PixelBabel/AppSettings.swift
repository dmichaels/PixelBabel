import SwiftUI
import Foundation

class DefaultAppSettings
{
    public static let pixelSize: Int = 10
    public static let colorMode: ColorMode = ColorMode.color
    public static let backgroundBufferSizeDefault: Int = 50
    public static let backgroundBufferSizeMax: Int = 250
}

class AppSettings: ObservableObject
{
    @Published var pixels: PixelMap
    @Published var colorMode: ColorMode = DefaultAppSettings.colorMode
    @Published var pixelSize: Int = DefaultAppSettings.pixelSize
    @Published var soundEnabled: Bool = true
    @Published var hapticEnabled: Bool = false
    @Published var randomFixedImage: Bool = false
    @Published var randomFixedImagePeriod: RandomFixedImagePeriod = RandomFixedImagePeriod.sometimes
    @Published var backgroundBufferEnabled: Bool = true
    @Published var backgroundBufferSize: Int = DefaultAppSettings.backgroundBufferSizeDefault
    @Published var automationEnabled: Bool = true
    @Published var automationSpeed: Double = 0.1

    init() {
        self.pixels = PixelMap(ScreenWidth, ScreenHeight,
                               scale: DefaultAppSettings.pixelSize,
                               mode: DefaultAppSettings.colorMode,
                               backgroundBufferSize: DefaultAppSettings.backgroundBufferSizeDefault)
    }
}
