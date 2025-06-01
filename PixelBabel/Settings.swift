import Foundation
import SwiftUI
import Utils

class DefaultSettings
{
    public static let ignoreSafeArea: Bool              = false
    public static let timerInterval: Double             = 0.2

    public static let viewScaling: Bool                 = CellGrid.Defaults.viewScaling
    public static let viewBackground: CellColor         = CellGrid.Defaults.viewBackground

    public static let cellSize: Int                     = CellGrid.Defaults.cellSize
    public static let cellSizeFit: Bool                 = CellGrid.Defaults.cellSizeFit
    public static let cellPadding: Int                  = CellGrid.Defaults.cellPadding
    public static let cellShape: CellShape              = CellGrid.Defaults.cellShape
    public static let cellColorMode: CellColorMode      = CellGrid.Defaults.cellColorMode
    public static let cellForeground: CellColor         = CellGrid.Defaults.cellForeground
    public static let cellAntialiasFade: Float          = CellGridView.Defaults.cellAntialiasFade
    public static let cellRoundedRectangleRadius: Float = CellGridView.Defaults.cellRoundedRectangleRadius
    public static let soundEnabled: Bool                = true
    public static let hapticEnabled: Bool               = true

    public static let gridColumns: Int                  = 50
    public static let gridRows: Int                     = 75

    public static let draggingThreshold: CGFloat        = 3.0
    public static let swipeDistance: CGFloat            = 100
    public static let updateMode: Bool                  = false

    public static let restrictShiftStrict: Bool         = false
    public static let centerCellGrid: Bool              = false
    public static let unscaledZoom: Bool                = false
}

class Settings: ObservableObject
{
    @Published var viewBackground: CellColor         = DefaultSettings.viewBackground
    @Published var viewScaling: Bool                 = DefaultSettings.viewScaling

    @Published var cellSize: Int                     = DefaultSettings.cellSize
    @Published var cellSizeFit: Bool                 = DefaultSettings.cellSizeFit
    @Published var cellPadding: Int                  = DefaultSettings.cellPadding
    @Published var cellShape: CellShape              = DefaultSettings.cellShape
    @Published var cellColorMode: CellColorMode      = DefaultSettings.cellColorMode
    @Published var cellAntialiasFade: Float          = DefaultSettings.cellAntialiasFade
    @Published var cellRoundedRectangleRadius: Float = DefaultSettings.cellRoundedRectangleRadius
    @Published var soundEnabled: Bool                = DefaultSettings.soundEnabled
    @Published var hapticEnabled: Bool               = DefaultSettings.hapticEnabled

    @Published var gridColumns: Int                  = DefaultSettings.gridColumns
    @Published var gridRows: Int                     = DefaultSettings.gridRows

    @Published var updateMode: Bool                  = DefaultSettings.updateMode
}
