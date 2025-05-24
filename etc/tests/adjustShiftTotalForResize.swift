import Foundation

let viewWidth: Int = 1161
let viewSize: Int = viewWidth
let viewAnchorFactor: Double = 0.5

typealias AdjustShiftTotalFunction = (Int, Int, Int, Int) -> Int

struct AdjustShiftTotal {
    public let function: AdjustShiftTotalFunction
    public let name: String
    init(_ function: @escaping AdjustShiftTotalFunction, _ name: String) {
        self.function = function
        self.name = name
    }
    public static let DEFAULT:  AdjustShiftTotal = AdjustShiftTotal(adjustShiftTotal,         "DEFAULT")
    public static let GPT:      AdjustShiftTotal = AdjustShiftTotal(adjustShiftTotalGPT,      "GPT")
    public static let GPTv2:    AdjustShiftTotal = AdjustShiftTotal(adjustShiftTotalGPTv2,    "GPTv2")
    public static let BRUTE:    AdjustShiftTotal = AdjustShiftTotal(adjustShiftTotalBrute,    "BRUTE")
    public static let ORIGINAL: AdjustShiftTotal = AdjustShiftTotal(adjustShiftTotalOriginal, "ORIGINAL")
}

func adjustShiftTotal(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int) -> Int {
    let viewCenter: Double = Double(viewSize) * viewAnchorFactor
    let round: (Double) -> Double = cellIncrement > 0 ? (cellSize % 2 == 0 ? ceil : floor)
                                                      : (cellSize % 2 == 0 ? floor : ceil)
    let cellsFromCenter: Int = Int(round((viewCenter - Double(shiftTotal)) / Double(cellSize)))
    return shiftTotal - (cellsFromCenter * cellIncrement)
}

func adjustShiftTotalBrute(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int) -> Int {
    var shiftTotal: Int = shiftTotal
    let step: Int = cellIncrement > 0 ? 1 : -1
    for increment in stride(from: 1, through: cellIncrement, by: step) {
        shiftTotal = adjustShiftTotal(viewSize: viewSize,
                                      cellSize: cellSize + increment - 1,
                                      cellIncrement: 1,
                                      shiftTotal: shiftTotal)
    }
    return shiftTotal
}

func adjustShiftTotalOriginal(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int) -> Int {
    let viewCenter: Double = Double(viewSize) * viewAnchorFactor
    let round: (Double) -> Double = cellSize % 2 == 0 ? ceil : floor
    let cellsFromCenter: Int = Int(round((viewCenter - Double(shiftTotal)) / Double(cellSize)))
    return shiftTotal - (cellsFromCenter * cellIncrement)
}

func adjustShiftTotalGPT(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int) -> Int {
    let oldCellSize: Int = cellSize
    let cellSize: Int = cellSize + cellIncrement
    let viewCenter = Double(viewSize) * viewAnchorFactor
    let oldIndex = Int(round((viewCenter - Double(shiftTotal)) / Double(oldCellSize)))
    let newShift = Int(round(viewCenter - Double(oldIndex) * Double(cellSize)))
    return newShift - (cellSize / 2) // i added to what gpt gave me based on observation: - cellSize / 2
}

func adjustShiftTotalGPTv2(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int) -> Int {
    let anchor = Double(viewSize) * viewAnchorFactor
    let oldSize = cellSize
    let newSize = cellSize + cellIncrement
    // The discrete cell index anchored by the old size
    let cellIndex = Int(round((anchor - Double(shiftTotal)) / Double(oldSize)))
    // Place the *same* cell index under the anchor, using the new size
    return Int(round(anchor - Double(cellIndex) * Double(newSize))) - (cellSize / 2)
}

func modulo(_ value: Int, _ modulus: Int) -> Int {
    let remainder: Int = value % modulus
    return remainder >= 0 ? remainder : remainder + modulus
}

func shiftOpposite(cellSize: Int, shiftX: Int, viewSizeExtra: Int) -> Int {
    return modulo(cellSize + shiftX - viewSizeExtra, cellSize)
}

func T(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int, f: AdjustShiftTotal, expect: (sht: Int?, sh: Int?, sho: Int?)? = nil) {
    let newShiftTotal: Int = f.function(viewSize, cellSize, cellIncrement, shiftTotal)
    let newCellSize: Int = cellSize + cellIncrement
    let newShiftCell: Int = newShiftTotal / newCellSize
    let newShift: Int = newShiftTotal % newCellSize
    let newViewSizeExtra: Int = viewSize % newCellSize
    let newShiftOpposite: Int = shiftOpposite(cellSize: newCellSize, shiftX: newShift, viewSizeExtra: newViewSizeExtra)
    let isAdjustmentEven: Bool = [0, 1].contains(abs(abs(newShiftOpposite) - abs(newShift)))
    var result: String = ""
    if (expect != nil) {
        var okay: Bool = true
        if ((expect!.sht != nil) && (expect!.sht! != newShiftTotal)) {
            okay = false
        }
        if ((expect!.sh != nil) && (expect!.sh! != newShift)) {
            okay = false
        }
        if ((expect!.sho != nil) && (expect!.sho! != newShiftOpposite)) {
            okay = false
        }
        result = okay ? "✓ OK" : "✗"
    }
    print((f.name + ">").padding(toLength: 10, withPad: " ", startingAt: 0) +
          "cs: \(String(format: "%3d", cellSize))  " +
          "[\(String(format: "%2+d", cellIncrement))]  " +
          "csht: \(String(format: "%4d", shiftTotal))  ->  " +
          "cs: \(String(format: "%3d", newCellSize))  " +
          "vwe: \(String(format: "%3d", newViewSizeExtra))  " +
          "sht: \(String(format: "%4d", newShiftTotal))  " +
          "shc: \(String(format: "%3d", newShiftCell))  " +
          "sh: \(String(format: "%3d", newShift))  " +
          "sho: \(String(format: "%3d", newShiftOpposite))  " +
          (isAdjustmentEven ? "even  " : "uneven") +
          ((expect != nil) ? " -> \(result)" : "")
    )
}

print()
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 1, shiftTotal:   0, f: AdjustShiftTotal.DEFAULT, expect: (sht:  nil, sh:  -4, sho:  5)) // from 129 to 130 by 1 -> OK
T(viewSize: viewWidth, cellSize: 130, cellIncrement: 1, shiftTotal:  -4, f: AdjustShiftTotal.DEFAULT, expect: (sht:  nil, sh:  -9, sho:  9)) // from 130 to 131 by 1 -> OK
T(viewSize: viewWidth, cellSize: 131, cellIncrement: 1, shiftTotal:  -9, f: AdjustShiftTotal.DEFAULT, expect: (sht:  nil, sh: -13, sho: 14)) // from 131 to 132 by 1 -> OK
T(viewSize: viewWidth, cellSize: 132, cellIncrement: 1, shiftTotal: -13, f: AdjustShiftTotal.DEFAULT, expect: (sht:  nil, sh: -18, sho: 18)) // from 132 to 133 by 1 -> OK
T(viewSize: viewWidth, cellSize: 133, cellIncrement: 1, shiftTotal: -18, f: AdjustShiftTotal.DEFAULT, expect: (sht:  nil, sh: -22, sho: 23)) // from 133 to 134 by 1 -> OK
T(viewSize: viewWidth, cellSize: 134, cellIncrement: 1, shiftTotal: -22, f: AdjustShiftTotal.DEFAULT, expect: (sht:  nil, sh: -27, sho: 27)) // from 134 to 135 by 1 -> OK

print()
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 1, shiftTotal:   0, f: AdjustShiftTotal.GPT,     expect: (sht:  nil, sh:  -4, sho:  5)) // from 129 to 130 by 1 -> WRONG -> sh:  -5 sho:  4
T(viewSize: viewWidth, cellSize: 130, cellIncrement: 1, shiftTotal:  -4, f: AdjustShiftTotal.GPT,     expect: (sht:  nil, sh:  -9, sho:  9)) // from 130 to 131 by 1 -> WRONG -> sh:  -8 sho: 10
T(viewSize: viewWidth, cellSize: 131, cellIncrement: 1, shiftTotal:  -9, f: AdjustShiftTotal.GPT,     expect: (sht:  nil, sh: -13, sho: 14)) // from 131 to 132 by 1 -> WRONG -> sh: -14 sho: 13
T(viewSize: viewWidth, cellSize: 132, cellIncrement: 1, shiftTotal: -13, f: AdjustShiftTotal.GPT,     expect: (sht:  nil, sh: -18, sho: 18)) // from 132 to 133 by 1 -> WRONG -> sh: -17 sho: 19
T(viewSize: viewWidth, cellSize: 133, cellIncrement: 1, shiftTotal: -18, f: AdjustShiftTotal.GPT,     expect: (sht:  nil, sh: -22, sho: 23)) // from 133 to 134 by 1 -> WRONG -> sh: -23 sho: 22
T(viewSize: viewWidth, cellSize: 134, cellIncrement: 1, shiftTotal: -22, f: AdjustShiftTotal.GPT,     expect: (sht:  nil, sh: -27, sho: 27)) // from 134 to 135 by 1 -> WRONG -> sh: -26 sho: 28

print()
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 1, shiftTotal:   0, f: AdjustShiftTotal.GPTv2,   expect: (sht:  nil, sh:  -4, sho:  5)) // from 129 to 130 by 1 -> WRONG -> sh:  -5 sho:  4
T(viewSize: viewWidth, cellSize: 130, cellIncrement: 1, shiftTotal:  -4, f: AdjustShiftTotal.GPTv2,   expect: (sht:  nil, sh:  -9, sho:  9)) // from 130 to 131 by 1 -> WRONG -> sh:  -8 sho: 10
T(viewSize: viewWidth, cellSize: 131, cellIncrement: 1, shiftTotal:  -9, f: AdjustShiftTotal.GPTv2,   expect: (sht:  nil, sh: -13, sho: 14)) // from 131 to 132 by 1 -> WRONG -> sh: -14 sho: 13
T(viewSize: viewWidth, cellSize: 132, cellIncrement: 1, shiftTotal: -13, f: AdjustShiftTotal.GPTv2,   expect: (sht:  nil, sh: -18, sho: 18)) // from 132 to 133 by 1 -> WRONG -> sh: -17 sho: 19
T(viewSize: viewWidth, cellSize: 133, cellIncrement: 1, shiftTotal: -18, f: AdjustShiftTotal.GPTv2,   expect: (sht:  nil, sh: -22, sho: 23)) // from 133 to 134 by 1 -> WRONG -> sh: -23 sho: 22
T(viewSize: viewWidth, cellSize: 134, cellIncrement: 1, shiftTotal: -22, f: AdjustShiftTotal.GPTv2,   expect: (sht:  nil, sh: -27, sho: 27)) // from 134 to 135 by 1 -> WRONG -> sh: -26 sho: 28

print()
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 2, shiftTotal:   0, f: AdjustShiftTotal.DEFAULT, expect: (sht:  nil, sh:  -9, sho:  9)) // from 129 to 131 by 2 -> WRONG -> sh:  -8 sho: 10
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 3, shiftTotal:   0, f: AdjustShiftTotal.DEFAULT, expect: (sht:  nil, sh: -13, sho: 14)) // from 129 to 132 by 3 -> WRONG -> sh: -12 sho: 15
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 4, shiftTotal:   0, f: AdjustShiftTotal.DEFAULT, expect: (sht:  nil, sh: -18, sho: 18)) // from 129 to 133 by 4 -> WRONG -> sh: -16 sho: 20
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 5, shiftTotal:   0, f: AdjustShiftTotal.DEFAULT, expect: (sht:  nil, sh: -22, sho: 23)) // from 129 to 134 by 5 -> WRONG -> sh: -20 sho: 25

print()
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 2, shiftTotal:   0, f: AdjustShiftTotal.GPT,     expect: (sht:  nil, sh:  -9, sho:  9)) // from 129 to 131 by 2 -> OK
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 3, shiftTotal:   0, f: AdjustShiftTotal.GPT,     expect: (sht:  nil, sh: -13, sho: 14)) // from 129 to 132 by 3 -> WRONG -> sh: -13 sho: 14
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 4, shiftTotal:   0, f: AdjustShiftTotal.GPT,     expect: (sht:  nil, sh: -18, sho: 18)) // from 129 to 133 by 4 -> OK
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 5, shiftTotal:   0, f: AdjustShiftTotal.GPT,     expect: (sht:  nil, sh: -22, sho: 23)) // from 129 to 134 by 5 -> WRONG -> sh: -23 sho: 22

print()
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 2, shiftTotal:   0, f: AdjustShiftTotal.GPTv2,   expect: (sht:  nil, sh:  -9, sho:  9)) // from 129 to 131 by 2 -> OK
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 3, shiftTotal:   0, f: AdjustShiftTotal.GPTv2,   expect: (sht:  nil, sh: -13, sho: 14)) // from 129 to 132 by 3 -> WRONG -> sh: -13 sho: 14
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 4, shiftTotal:   0, f: AdjustShiftTotal.GPTv2,   expect: (sht:  nil, sh: -18, sho: 18)) // from 129 to 133 by 4 -> OK
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 5, shiftTotal:   0, f: AdjustShiftTotal.GPTv2,   expect: (sht:  nil, sh: -22, sho: 23)) // from 129 to 134 by 5 -> WRONG -> sh: -23 sho: 22

print()
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 2, shiftTotal:   0, f: AdjustShiftTotal.BRUTE,   expect: (sht: nil, sh:  -9, sho:  9)) // from 129 to 131 by 2 -> OK
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 3, shiftTotal:   0, f: AdjustShiftTotal.BRUTE,   expect: (sht: nil, sh: -13, sho: 14)) // from 129 to 132 by 3 -> OK
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 4, shiftTotal:   0, f: AdjustShiftTotal.BRUTE,   expect: (sht: nil, sh: -18, sho: 18)) // from 129 to 133 by 4 -> OK
T(viewSize: viewWidth, cellSize: 129, cellIncrement: 5, shiftTotal:   0, f: AdjustShiftTotal.BRUTE,   expect: (sht: nil, sh: -22, sho: 23)) // from 129 to 134 by 5 -> OK

// Non viewWidth (1161) tests ...
//
print()
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal:   0, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -2, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal:  -1, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -3, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal:  -2, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -4, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal:  -3, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -5, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal:  -4, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -6, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal:  -5, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -8, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal:  -6, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -9, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal:  -7, f: AdjustShiftTotal.DEFAULT, expect: (sht: -10, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal:  -8, f: AdjustShiftTotal.DEFAULT, expect: (sht: -11, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal:  -9, f: AdjustShiftTotal.DEFAULT, expect: (sht: -12, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal: -10, f: AdjustShiftTotal.DEFAULT, expect: (sht: -14, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal: -11, f: AdjustShiftTotal.DEFAULT, expect: (sht: -15, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal: -12, f: AdjustShiftTotal.DEFAULT, expect: (sht: -16, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal: -13, f: AdjustShiftTotal.DEFAULT, expect: (sht: -17, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal: -14, f: AdjustShiftTotal.DEFAULT, expect: (sht: -18, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal: -15, f: AdjustShiftTotal.DEFAULT, expect: (sht: -20, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 1, shiftTotal: -16, f: AdjustShiftTotal.DEFAULT, expect: (sht: -21, sh: nil, sho: nil))

T(viewSize: 20,        cellSize:   5, cellIncrement: 2, shiftTotal:   0, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -4, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 2, shiftTotal:  -1, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -5, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 2, shiftTotal:  -2, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -6, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 2, shiftTotal:  -3, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -7, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 2, shiftTotal:  -4, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -8, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 2, shiftTotal:  -5, f: AdjustShiftTotal.DEFAULT, expect: (sht: -11, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 2, shiftTotal:  -6, f: AdjustShiftTotal.DEFAULT, expect: (sht: -12, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 2, shiftTotal:  -7, f: AdjustShiftTotal.DEFAULT, expect: (sht: -13, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 2, shiftTotal:  -8, f: AdjustShiftTotal.DEFAULT, expect: (sht: -14, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 2, shiftTotal:  -9, f: AdjustShiftTotal.DEFAULT, expect: (sht: -15, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 2, shiftTotal: -10, f: AdjustShiftTotal.DEFAULT, expect: (sht: -18, sh: nil, sho: nil))
T(viewSize: 20,        cellSize:   5, cellIncrement: 2, shiftTotal: -11, f: AdjustShiftTotal.DEFAULT, expect: (sht: -19, sh: nil, sho: nil))

T(viewSize: 17,        cellSize:   5, cellIncrement: 1, shiftTotal:   0, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -1, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 1, shiftTotal:  -1, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -2, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 1, shiftTotal:  -2, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -4, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 1, shiftTotal:  -3, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -5, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 1, shiftTotal:  -4, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -6, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 1, shiftTotal:  -5, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -7, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 1, shiftTotal:  -6, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -8, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 1, shiftTotal:  -7, f: AdjustShiftTotal.DEFAULT, expect: (sht: -10, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 1, shiftTotal:  -8, f: AdjustShiftTotal.DEFAULT, expect: (sht: -11, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 1, shiftTotal:  -9, f: AdjustShiftTotal.DEFAULT, expect: (sht: -12, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 1, shiftTotal: -10, f: AdjustShiftTotal.DEFAULT, expect: (sht: -13, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 1, shiftTotal: -11, f: AdjustShiftTotal.DEFAULT, expect: (sht: -14, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 1, shiftTotal: -12, f: AdjustShiftTotal.DEFAULT, expect: (sht: -16, sh: nil, sho: nil))

T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal:   0, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -2, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal:  -1, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -3, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal:  -2, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -6, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal:  -3, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -7, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal:  -4, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -8, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal:  -5, f: AdjustShiftTotal.DEFAULT, expect: (sht:  -9, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal:  -6, f: AdjustShiftTotal.DEFAULT, expect: (sht: -10, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal:  -7, f: AdjustShiftTotal.DEFAULT, expect: (sht: -13, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal:  -8, f: AdjustShiftTotal.DEFAULT, expect: (sht: -14, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal:  -9, f: AdjustShiftTotal.DEFAULT, expect: (sht: -15, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal: -10, f: AdjustShiftTotal.DEFAULT, expect: (sht: -16, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal: -11, f: AdjustShiftTotal.DEFAULT, expect: (sht: -17, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal: -12, f: AdjustShiftTotal.DEFAULT, expect: (sht: -20, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal: -13, f: AdjustShiftTotal.DEFAULT, expect: (sht: -21, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal: -14, f: AdjustShiftTotal.DEFAULT, expect: (sht: -22, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal: -15, f: AdjustShiftTotal.DEFAULT, expect: (sht: -23, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal: -16, f: AdjustShiftTotal.DEFAULT, expect: (sht: -24, sh: nil, sho: nil))
T(viewSize: 17,        cellSize:   5, cellIncrement: 2, shiftTotal: -17, f: AdjustShiftTotal.DEFAULT, expect: (sht: -27, sh: nil, sho: nil))
