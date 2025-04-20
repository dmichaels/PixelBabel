import Foundation
import SwiftUI

class DefaultSettings: ObservableObject
{
    @Published var displayWidth: Int                 = PixelMap.Defaults.displayWidth
    @Published var displayHeight: Int                = PixelMap.Defaults.displayWidth
    @Published var displayScale: CGFloat             = PixelMap.Defaults.displayScale
    @Published var displayScaling: Bool              = PixelMap.Defaults.displayScaling
    @Published var cellSize: Int                     = PixelMap.Defaults.cellSize
    @Published var cellSizeNeat: Bool                = PixelMap.Defaults.cellSizeNeat
    @Published var cellPadding: Int                  = PixelMap.Defaults.cellPadding
    @Published var cellBleeds: Bool                  = PixelMap.Defaults.cellBleeds
    @Published var cellShape: PixelShape             = PixelMap.Defaults.cellShape
    @Published var cellColorMode: ColorMode          = PixelMap.Defaults.cellColorMode
    @Published var cellBackground: PixelValue        = PixelMap.Defaults.cellBackground
    @Published var cellAntialiasFade: Float          = PixelMap.Defaults.cellAntialiasFade
    @Published var cellRoundedRectangleRadius: Float = PixelMap.Defaults.cellRoundedRectangleRadius
    @Published var cellLimitUpdate: Bool             = PixelMap.Defaults.cellLimitUpdate
    @Published var cellCaching: Bool                 = PixelMap.Defaults.cellCaching
}
