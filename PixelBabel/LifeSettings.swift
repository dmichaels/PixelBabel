import SwiftUI
import CellGridView

class DefaultLifeSettings
{
    public static let cellActiveColor: CellColor = CellColor(Color.red)
    public static let cellInactiveColor: CellColor = CellColor(Color.white)
}

class LifeSettings: Settings
{
    @Published var cellActiveColor: CellColor = CellColor(Color.red)
    @Published var cellInactiveColor: CellColor = CellColor(Color.white)
}
