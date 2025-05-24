import Foundation

let viewAnchorFactor: Double = 0.5

struct AdjustShiftTotalData {
    typealias Expect = (sht: Int?, sh: Int?, sho: Int?)
    let viewSize: Int
    let cellSize: Int
    let cellIncrement: Int
    let shiftTotal: Int
    let expect: Expect?
    init(vs viewSize: Int, cs cellSize: Int, ci cellIncrement: Int, sht shiftTotal: Int, ex expect: Expect?) {
        self.viewSize = viewSize
        self.cellSize = cellSize
        self.cellIncrement = cellIncrement
        self.shiftTotal = shiftTotal
        self.expect = expect
    }
}

struct AdjustShiftTotal {
    typealias Function = (Int, Int, Int, Int) -> Int
    public let function: Function
    public let name: String
    init(_ function: @escaping Function, _ name: String) {
        self.function = function
        self.name = name
    }
    public static let DEFAULT:  AdjustShiftTotal = AdjustShiftTotal(adjustShiftTotal, "DEFAULT")
    public static let ORIGINAL: AdjustShiftTotal = AdjustShiftTotal(adjustShiftTotal, "ORIGINAL")
}

func adjustShiftTotal(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int) -> Int {
    // 
    // Actually think this MIGHT be right but NOT we've been calculating some thing wrong manually for testing.
    // So for example for the below, the center point is in cell 2 at offset 3 within that cell (2#3); previously
    // we were thinking that that is the point that we wanted to maintain constantly centered on resize, but that
    // is not really correct; we should rather be dealing with this in percentages (i.e. floating point), so rather
    // than saying that cell 2#3 should remain centered we should say cell 2.6 should remain centered; 2.6 being
    // cell 2 and 0.6 being the cell offset within the cell (3) divided by the cell size (5); and if we then
    // increment to cell size 7 (from 5) the 2.6 for that cell size (7) is cell 2#4.2 (4.2 == 7 * 0.6).
    //
    // viewSize:      20
    // cellSize:       5
    // cellIncrement: +2
    // shiftTotal:    -3
    //
    // What this means is that for this example, whereas we'd previously confidently said that resuling shiftTotal,
    // upon resize (from 5 to 7) should be -7 it should actually be -8. Still may be some rounding (floor vs ceil etc)
    // issues with this but this is a crucial distinction we just realized to be the case. Need to manually redo test cases.
    //
    let viewCenter: Double = Double(viewSize) * viewAnchorFactor
    let cellCenter: Double = (viewCenter - Double(shiftTotal)) / Double(cellSize)
    let shiftDelta: Double = cellCenter * Double(cellSize + cellIncrement) - (viewCenter - Double(shiftTotal))
    let round: (Double) -> Double = cellIncrement < 0 ? (cellSize % 2 == 0 ? ceil : floor) : (cellSize % 2 == 0 ? floor : ceil)
    // let round = floor
    return Int(round(Double(shiftTotal) - shiftDelta))
}

func adjustShiftTotalOriginal(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int) -> Int {
    let viewCenter: Double = Double(viewSize) * viewAnchorFactor
    let round: (Double) -> Double = cellIncrement > 0 ? (cellSize % 2 == 0 ? ceil : floor)
                                                      : (cellSize % 2 == 0 ? floor : ceil)
    let cellCenter: Int = Int(round((viewCenter - Double(shiftTotal)) / Double(cellSize)))
    return shiftTotal - (cellCenter * cellIncrement)
}

func test(vs viewSize: Int, cs cellSize: Int, ci cellIncrement: Int, sht shiftTotal: Int,
       ex expect: AdjustShiftTotalData.Expect? = nil, f: AdjustShiftTotal? = nil) {

    func modulo(_ value: Int, _ modulus: Int) -> Int {
        let remainder: Int = value % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }

    func shiftOpposite(cellSize: Int, shiftX: Int, viewSizeExtra: Int) -> Int {
        return modulo(cellSize + shiftX - viewSizeExtra, cellSize)
    }

    let f: AdjustShiftTotal = f ?? AdjustShiftTotal.DEFAULT
    let newShiftTotal: Int = f.function(viewSize, cellSize, cellIncrement, shiftTotal)
    let newCellSize: Int = cellSize + cellIncrement
    let newShiftCell: Int = newShiftTotal / newCellSize
    let newShift: Int = newShiftTotal % newCellSize
    let newViewSizeExtra: Int = viewSize % newCellSize
    let newShiftOppositeTest: Bool = (expect != nil) && (expect!.sho != nil)
    let newShiftOpposite: Int? = newShiftOppositeTest ? shiftOpposite(cellSize: newCellSize, shiftX: newShift, viewSizeExtra: newViewSizeExtra) : nil
    let newShiftOppositeEven: Bool? = newShiftOppositeTest ? [0, 1].contains(abs(abs(newShiftOpposite!) - abs(newShift))) : nil
    var result: String = ""
    if (expect != nil) {
        var nchecks: Int = 0
        var okay: Bool = true
        if (expect!.sht != nil) {
            if (expect!.sht! != newShiftTotal) { okay = false }
            nchecks += 1
        }
        if (expect!.sh != nil) {
            if (expect!.sh! != newShift) { okay = false }
            nchecks += 1
        }
        if (expect!.sho != nil) {
            if (expect!.sho! != newShiftOpposite!) { okay = false }
            nchecks += 1
        }
        if (nchecks > 0) { result = okay ? "✓ OK" : "✗" } else { result = "?" }
    }
    print((f.name + ">").padding(toLength: 12, withPad: " ", startingAt: 0) +
          "vs: \(String(format: "%3d", viewSize))  " +
          "cs: \(String(format: "%3d", cellSize)) " +
          "[\(String(format: "%2+d", cellIncrement))]  " +
          "sht: \(String(format: "%4d", shiftTotal))  >>>  " +
          "cs: \(String(format: "%3d", newCellSize))  " +
       // "vse: \(String(format: "%3d", newViewSizeExtra))  " +
          "sht: \(String(format: "%4d", newShiftTotal))  " +
          "shc: \(String(format: "%3d", newShiftCell))  " +
          "sh: \(String(format: "%3d", newShift))  " +
          "sho: \(newShiftOppositeTest ? String(format: "%2d-", newShiftOpposite!) : " -  ")" +
          (newShiftOppositeTest ? (newShiftOppositeEven! ? "E" : "U") : "") +
          ((expect != nil) ? "  \(result)" : "")
    )
}

func test(_ data: [AdjustShiftTotalData], f: AdjustShiftTotal? = nil) {
    let f: AdjustShiftTotal = f ?? AdjustShiftTotal.DEFAULT
    print()
    for item in data {
        test(vs: item.viewSize, cs: item.cellSize, ci: item.cellIncrement, sht: item.shiftTotal, ex: item.expect, f: f)
    }
}


let dataIncOne: [AdjustShiftTotalData] =  [
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht:   0, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht:  -1, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht:  -2, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht:  -3, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht:  -4, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht:  -5, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht:  -6, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht:  -7, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht:  -8, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht:  -9, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht: -10, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht: -11, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht: -12, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht: -13, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht: -14, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht: -15, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht: -16, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 1, sht: -17, ex: (sht: nil, sh: nil, sho: 0))
]

let dataIncTwo: [AdjustShiftTotalData] =  [
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht:   0, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht:  -1, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht:  -2, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht:  -3, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht:  -4, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht:  -5, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht:  -6, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht:  -7, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht:  -8, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht:  -9, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht: -10, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht: -11, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht: -12, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht: -13, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht: -14, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht: -15, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht: -16, ex: (sht: nil, sh: nil, sho: 0)),
    AdjustShiftTotalData(vs: 20, cs: 5, ci: 2, sht: -17, ex: (sht: nil, sh: nil, sho: 0))
]

test(dataIncOne, f: AdjustShiftTotal.DEFAULT)
test(dataIncTwo, f: AdjustShiftTotal.DEFAULT)
