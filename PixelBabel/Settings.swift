import Foundation
import SwiftUI
import Utils

class DefaultSettings
{
    public static let ignoreSafeArea: Bool              = true
    public static let timerInterval: Double             = 0.2
    public static let displayScaling: Bool              = CellGrid.Defaults.displayScaling

    public static let cellSize: Int                     = CellGrid.Defaults.cellSize
    public static let cellSizeNeat: Bool                = CellGrid.Defaults.cellSizeNeat
    public static let cellPadding: Int                  = CellGrid.Defaults.cellPadding
    public static let cellShape: CellShape              = CellGrid.Defaults.cellShape
    public static let cellColorMode: CellColorMode      = CellGrid.Defaults.cellColorMode
    public static let cellForeground: CellColor         = CellGrid.Defaults.cellForeground
    public static let cellBackground: CellColor         = CellGrid.Defaults.cellBackground
    public static let cellAntialiasFade: Float          = CellGridView.Defaults.cellAntialiasFade
    public static let cellRoundedRectangleRadius: Float = CellGridView.Defaults.cellRoundedRectangleRadius
    public static let automationEnabled: Bool           = true
    public static let automationSpeed: Double           = 0.1
    public static let soundEnabled: Bool                = true
    public static let hapticEnabled: Bool               = true

    public static let draggingThreshold: CGFloat        = 3.0
    public static let swipeDistance: CGFloat            = 100
    public static let updateMode: Bool                  = false
}

class Settings: ObservableObject
{
    @Published var displayScaling: Bool              = DefaultSettings.displayScaling

    @Published var cellSize: Int                     = DefaultSettings.cellSize
    @Published var cellSizeNeat: Bool                = DefaultSettings.cellSizeNeat
    @Published var cellPadding: Int                  = DefaultSettings.cellPadding
    @Published var cellShape: CellShape              = DefaultSettings.cellShape
    @Published var cellColorMode: CellColorMode      = DefaultSettings.cellColorMode
    @Published var cellBackground: CellColor         = DefaultSettings.cellBackground
    @Published var cellAntialiasFade: Float          = DefaultSettings.cellAntialiasFade
    @Published var cellRoundedRectangleRadius: Float = DefaultSettings.cellRoundedRectangleRadius
    @Published var automationEnabled: Bool           = DefaultSettings.automationEnabled
    @Published var automationSpeed: Double           = DefaultSettings.automationSpeed
    @Published var soundEnabled: Bool                = DefaultSettings.soundEnabled
    @Published var hapticEnabled: Bool               = DefaultSettings.hapticEnabled

    @Published var updateMode: Bool                  = DefaultSettings.updateMode
}
