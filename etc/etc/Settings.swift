import Foundation
import SwiftUI

class DefaultSettings
{
    public static let displayScaling: Bool              = PixelMap.Defaults.displayScaling

    public static let cellSize: Int                     = PixelMap.Defaults.cellSize
    public static let cellSizeNeat: Bool                = PixelMap.Defaults.cellSizeNeat
    public static let cellPadding: Int                  = PixelMap.Defaults.cellPadding
    public static let cellBleeds: Bool                  = PixelMap.Defaults.cellBleeds
    public static let cellShape: PixelShape             = PixelMap.Defaults.cellShape
    public static let cellColorMode: ColorMode          = PixelMap.Defaults.cellColorMode
    public static let cellBackground: PixelValue        = PixelMap.Defaults.cellBackground
    public static let cellAntialiasFade: Float          = PixelMap.Defaults.cellAntialiasFade
    public static let cellRoundedRectangleRadius: Float = PixelMap.Defaults.cellRoundedRectangleRadius
    public static let cellPreferredSizeMarginMax: Int   = PixelMap.Defaults.cellPreferredSizeMarginMax
    public static let cellCaching: Bool                 = PixelMap.Defaults.cellCaching
    public static let cellLimitUpdate: Bool             = PixelMap.Defaults.cellLimitUpdate
    public static let automationEnabled: Bool           = true
    public static let automationSpeed: Double           = 0.1

    public static let draggingThreshold: CGFloat        = 3.0
    public static let updateMode: Bool                  = false
}

class Settings: ObservableObject
{
    @Published var displayScaling: Bool              = DefaultSettings.displayScaling

    @Published var cellSize: Int                     = DefaultSettings.cellSize
    @Published var cellSizeNeat: Bool                = DefaultSettings.cellSizeNeat
    @Published var cellPadding: Int                  = DefaultSettings.cellPadding
    @Published var cellBleeds: Bool                  = DefaultSettings.cellBleeds
    @Published var cellShape: PixelShape             = DefaultSettings.cellShape
    @Published var cellColorMode: ColorMode          = DefaultSettings.cellColorMode
    @Published var cellBackground: PixelValue        = DefaultSettings.cellBackground
    @Published var cellAntialiasFade: Float          = DefaultSettings.cellAntialiasFade
    @Published var cellRoundedRectangleRadius: Float = DefaultSettings.cellRoundedRectangleRadius
    @Published var cellPreferredSizeMarginMax: Int   = DefaultSettings.cellPreferredSizeMarginMax
    @Published var cellCaching: Bool                 = DefaultSettings.cellCaching
    @Published var cellLimitUpdate: Bool             = DefaultSettings.cellLimitUpdate
    @Published var automationEnabled: Bool           = DefaultSettings.automationEnabled
    @Published var automationSpeed: Double           = DefaultSettings.automationSpeed

    @Published var updateMode: Bool                  = DefaultSettings.updateMode
}
