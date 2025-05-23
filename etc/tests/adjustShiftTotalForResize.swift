import Foundation

typealias AdjustShiftTotal = (Int, Int, Int, Int, Double) -> Int

func adjustShiftTotal(viewSize: Int, cellSize: Int, cellSizeIncrement: Int,
                      shiftTotal: Int, viewAnchorFactor: Double = 0.5) -> Int {
    let viewCenter: Double = Double(viewSize) * viewAnchorFactor
    let round: (Double) -> Double = cellSizeIncrement > 0 ? (cellSize % 2 == 0 ? ceil : floor)
                                                          : (cellSize % 2 == 0 ? floor : ceil)
    let cellsFromCenter: Int = Int(round((viewCenter - Double(shiftTotal)) / Double(cellSize)))
    return shiftTotal - (cellsFromCenter * cellSizeIncrement)
}

func adjustShiftTotalBrute(viewSize: Int, cellSize: Int, cellSizeIncrement: Int,
                           shiftTotal: Int, viewAnchorFactor: Double = 0.5) -> Int {
    var shiftTotal: Int = shiftTotal
    let step: Int = cellSizeIncrement > 0 ? 1 : -1
    for increment in stride(from: 1, through: cellSizeIncrement, by: step) {
        shiftTotal = adjustShiftTotal(viewSize: viewSize,
                                      cellSize: cellSize + increment - 1,
                                      cellSizeIncrement: 1,
                                      shiftTotal: shiftTotal,
                                      viewAnchorFactor: viewAnchorFactor)
    }
    return shiftTotal
}

func adjustShiftTotalGPT(viewSize: Int, cellSize: Int, cellSizeIncrement: Int,
                         shiftTotal: Int, viewAnchorFactor: Double = 0.5) -> Int {

    let oldCellSize: Int = cellSize
    let cellSize: Int = cellSize + cellSizeIncrement
    let viewCenter = Double(viewSize) * viewAnchorFactor
    let oldIndex = Int(round((viewCenter - Double(shiftTotal)) / Double(oldCellSize)))
    let newShift = Int(round(viewCenter - Double(oldIndex) * Double(cellSize)))
    return newShift - (cellSize / 2)
}

func modulo(_ value: Int, _ modulus: Int) -> Int {
    let remainder: Int = value % modulus
    return remainder >= 0 ? remainder : remainder + modulus
}

func shiftOpposite(cellSize: Int, shiftX: Int, viewWidthExtra: Int) -> Int {
    return modulo(cellSize + shiftX - viewWidthExtra, cellSize)
}

let viewWidth: Int = 1161
let viewSize: Int = viewWidth
let viewAnchorFactor: Double = 0.5

func test(cellSize: Int, cellSizeIncrement: Int, shiftTotal: Int, f: AdjustShiftTotal = adjustShiftTotal) {
    let newShiftTotal: Int = f(viewSize, cellSize, cellSizeIncrement, shiftTotal, viewAnchorFactor)
    let newCellSize: Int = cellSize + cellSizeIncrement
    let newShiftCell: Int = newShiftTotal / newCellSize
    let newShift: Int = newShiftTotal % newCellSize
    let newViewSizeExtra: Int = viewSize % newCellSize
    let newShiftOposite: Int = shiftOpposite(cellSize: newCellSize, shiftX: newShift, viewWidthExtra: newViewSizeExtra)
    let isAdjustmentEven: Bool = [0, 1].contains(abs(abs(newShiftOposite) - abs(newShift)))
    print("cs: \(String(format: "%4d", cellSize))  " +
          "ci: \(String(format: "%2d", cellSizeIncrement))  " +
          "csht: \(String(format: "%4d", shiftTotal))  ->  " +
          "cs: \(String(format: "%4d", newCellSize))  " +
          "vwe: \(String(format: "%4d", newViewSizeExtra))  " +
          "sht: \(String(format: "%4d", newShiftTotal))  " +
          "shc: \(String(format: "%4d", newShiftCell))  " +
          "sh: \(String(format: "%4d", newShift))  " +
          "shr: \(String(format: "%4d", shiftOpposite(cellSize: newCellSize, shiftX: newShift, viewWidthExtra: newViewSizeExtra)))  " +
          "even: \(isAdjustmentEven)"
    )
}



// test(cellSize: 130, cellSizeIncrement: 1, shiftTotal:  -4, f: adjustShiftTotalBrute) // -> from 130 to 131 by 1 -> sh:  -9 shr:  9
// test(cellSize: 130, cellSizeIncrement: 1, shiftTotal:  -4, f: adjustShiftTotal) // -> from 130 to 131 by 1 -> sh:  -9 shr:  9

print()
test(cellSize: 129, cellSizeIncrement: 1, shiftTotal:   0, f: adjustShiftTotal) // -> from 129 to 130 by 1 -> sh:  -4 shr:  5 -> OK
test(cellSize: 130, cellSizeIncrement: 1, shiftTotal:  -4, f: adjustShiftTotal) // -> from 130 to 131 by 1 -> sh:  -9 shr:  9 -> OK
test(cellSize: 131, cellSizeIncrement: 1, shiftTotal:  -9, f: adjustShiftTotal) // -> from 131 to 132 by 1 -> sh: -13 shr: 14 -> OK
test(cellSize: 132, cellSizeIncrement: 1, shiftTotal: -13, f: adjustShiftTotal) // -> from 132 to 133 by 1 -> sh: -18 shr: 18 -> OK
test(cellSize: 133, cellSizeIncrement: 1, shiftTotal: -18, f: adjustShiftTotal) // -> from 133 to 134 by 1 -> sh: -22 shr: 23 -> OK
test(cellSize: 134, cellSizeIncrement: 1, shiftTotal: -22, f: adjustShiftTotal) // -> from 134 to 135 by 1 -> sh: -27 shr: 27 -> OK

print()
test(cellSize: 129, cellSizeIncrement: 1, shiftTotal:   0, f: adjustShiftTotalGPT) // -> from 129 to 130 by 1 -> sh:  -5 shr:  4 -> WRONG should be sh:  -4 shr:  5
test(cellSize: 130, cellSizeIncrement: 1, shiftTotal:  -4, f: adjustShiftTotalGPT) // -> from 130 to 131 by 1 -> sh:  -8 shr: 10 -> WRONG should be sh:  -9 shr:  9
test(cellSize: 131, cellSizeIncrement: 1, shiftTotal:  -9, f: adjustShiftTotalGPT) // -> from 131 to 132 by 1 -> sh: -14 shr: 13 -> WRONG should be sh: -13 shr: 14
test(cellSize: 132, cellSizeIncrement: 1, shiftTotal: -13, f: adjustShiftTotalGPT) // -> from 132 to 133 by 1 -> sh: -17 shr: 19 -> WRONG should be sh: -18 shr: 18
test(cellSize: 133, cellSizeIncrement: 1, shiftTotal: -18, f: adjustShiftTotalGPT) // -> from 133 to 134 by 1 -> sh: -23 shr: 22 -> WRONG should be sh: -23 shr: 22
test(cellSize: 134, cellSizeIncrement: 1, shiftTotal: -22, f: adjustShiftTotalGPT) // -> from 134 to 135 by 1 -> sh: -26 shr: 28 -> WRONG should be sh: -27 shr: 27

print()
test(cellSize: 129, cellSizeIncrement: 2, shiftTotal:   0, f: adjustShiftTotalGPT) // -> from 129 to 131 by 2 -> sh: -75 shr: 74 -> WRONG should be sh:  -9 shr:  9
test(cellSize: 129, cellSizeIncrement: 3, shiftTotal:   0, f: adjustShiftTotalGPT) // -> from 129 to 132 by 3 -> sh: -80 shr: 79 -> WRONG should be sh: -13 shr: 14
test(cellSize: 129, cellSizeIncrement: 4, shiftTotal:   0, f: adjustShiftTotalGPT) // -> from 129 to 133 by 4 -> sh: -85 shr: 84 -> WRONG should be sh: -18 shr: 18
test(cellSize: 129, cellSizeIncrement: 5, shiftTotal:   0, f: adjustShiftTotalGPT) // -> from 129 to 134 by 5 -> sh: -90 shr: 89 -> WRONG should be sh: -22 shr: 23

print()
test(cellSize: 129, cellSizeIncrement: 2, shiftTotal:   0, f: adjustShiftTotal) // -> from 129 to 131 by 2 -> sh:  -8 shr: 10 -> WRONG should be sh:  -9 shr:  9
test(cellSize: 129, cellSizeIncrement: 3, shiftTotal:   0, f: adjustShiftTotal) // -> from 129 to 132 by 3 -> sh: -12 shr: 15 -> WRONG should be sh: -13 shr: 14
test(cellSize: 129, cellSizeIncrement: 4, shiftTotal:   0, f: adjustShiftTotal) // -> from 129 to 133 by 4 -> sh: -16 shr: 20 -> WRONG should be sh: -18 shr: 18
test(cellSize: 129, cellSizeIncrement: 5, shiftTotal:   0, f: adjustShiftTotal) // -> from 129 to 134 by 5 -> sh: -20 shr: 25 -> WRONG should be sh: -22 shr: 23

print()
test(cellSize: 129, cellSizeIncrement: 2, shiftTotal:   0, f: adjustShiftTotalBrute) // -> from 129 to 131 by 2 -> sh:  -9 shr:  9 -> OK
test(cellSize: 129, cellSizeIncrement: 3, shiftTotal:   0, f: adjustShiftTotalBrute) // -> from 129 to 132 by 3 -> sh: -13 shr: 14 -> OK
test(cellSize: 129, cellSizeIncrement: 4, shiftTotal:   0, f: adjustShiftTotalBrute) // -> from 129 to 133 by 4 -> sh: -18 shr: 18 -> OK
test(cellSize: 129, cellSizeIncrement: 5, shiftTotal:   0, f: adjustShiftTotalBrute) // -> from 129 to 134 by 5 -> sh: -22 shr: 23 -> OK
