import Foundation

extension String {

    func lpad(_ length: Int, _ pad: Character = " ") -> String {
        let selfLength = self.count
        guard selfLength < length else { return self }
        return String(repeating: pad, count: length - selfLength) + self
    }

    func rpad(_ length: Int, _ pad: Character = " ") -> String {
        let selfLength = self.count
        guard selfLength < length else { return self }
        return self + String(repeating: pad, count: length - selfLength)
    }
}

let viewAnchorFactor: Double = 0.5

struct AdjustShiftTotalData {
    typealias Expect = (sht: Int?, sh: Int?, sho: Int?)
    let viewSize: Int
    let cellSize: Int
    let cellIncrement: Int
    let shiftTotal: Int
    let expect: Expect?
    let confirmed: Bool
    let debug: Bool
    init(vs viewSize: Int, cs cellSize: Int, ci cellIncrement: Int, sht shiftTotal: Int,
         expect: Expect?, confirmed: Bool = false, debug: Bool = false) {
        self.viewSize = viewSize
        self.cellSize = cellSize
        self.cellIncrement = cellIncrement
        self.shiftTotal = shiftTotal
        self.expect = expect
        self.confirmed = confirmed
        self.debug = debug
    }
}

struct AdjustShiftTotal {
    typealias Function = (Int, Int, Int, Int) -> Int
    typealias DebugFunction = (Int, Int, Int, Int) -> String
    public let function: Function
    public let name: String
    public let debug: DebugFunction?
    init(_ function: @escaping Function, _ name: String, debug: DebugFunction?) {
        self.function = function
        self.name = name
        self.debug = debug
    }
    public static let DEFAULT:  AdjustShiftTotal = AdjustShiftTotal(adjustShiftTotal, "DEFAULT",  debug: adjustShiftTotalDebug)
    public static let ORIGINAL: AdjustShiftTotal = AdjustShiftTotal(adjustShiftTotal, "ORIGINAL", debug: nil)
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
    let viewCenterAdjusted: Double = viewCenter - Double(shiftTotal)
    let cellCenter: Double = viewCenterAdjusted / Double(cellSize)
    let shiftDelta: Double = cellCenter * Double(cellSize + cellIncrement) - viewCenterAdjusted
    // let round: (Double) -> Double = cellIncrement < 0 ? (cellSize % 2 == 0 ? ceil : floor) : (cellSize % 2 == 0 ? floor : ceil)
    let round: (Double) -> Double = floor
    let shiftTotal: Int = Int(round(Double(shiftTotal) - shiftDelta))
    return shiftTotal
}

struct AdjustShiftTotalDebugData {

    public let viewSize: Int
    public let cellSize: Int
    public let cellIncrement: Int
    public let shiftTotal: Int

    public let viewCenter: Double
    public let viewCenterAdjusted: Double
    public let cellCenter: Double
    public let cellCenterIndex: String

    public let resultCellSize: Int
    public let resultCellCenterIndex: String
    public let resultShiftTotal: Int
    public let shiftDelta: Double
}

func adjustShiftTotalDebugData(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int) -> AdjustShiftTotalDebugData {

    func cellCenterIndexString(_ cellCenter: Double, _ cellSize: Int) -> String {
        let cellIndex: Int = Int(cellCenter)
        let cellIndexOffset: Double = (cellCenter - Double(cellIndex)) * Double(cellSize)
        let cellIndexOffsetEven: Bool = Double(Int(cellIndexOffset)) == cellIndexOffset
        return "\(cellIndex)#\(cellIndexOffsetEven ? String(Int(cellIndexOffset)) : String(format: "%.1f", cellIndexOffset))"
    }

    let viewCenter:            Double = Double(viewSize) * viewAnchorFactor
    let viewCenterAdjusted:    Double = viewCenter - Double(shiftTotal)
    let cellCenter:            Double = viewCenterAdjusted / Double(cellSize)
    let cellCenterIndex:       String = cellCenterIndexString(cellCenter, cellSize)
    let resultCellSize:        Int    = cellSize + cellIncrement
    let resultCellCenterIndex: String = cellCenterIndexString(cellCenter, resultCellSize)
    let shiftDelta:            Double = cellCenter * Double(cellSize + cellIncrement) - viewCenterAdjusted
    let resultShiftTotal:      Int    = Int(round(Double(shiftTotal) - shiftDelta))

    return AdjustShiftTotalDebugData(viewSize:              viewSize,
                                     cellSize:              cellSize,
                                     cellIncrement:         cellIncrement,
                                     shiftTotal:            shiftTotal,
                                     viewCenter:            viewCenter,
                                     viewCenterAdjusted:    viewCenterAdjusted,
                                     cellCenter:            cellCenter,
                                     cellCenterIndex:       cellCenterIndex,
                                     resultCellSize:        resultCellSize,
                                     resultCellCenterIndex: resultCellCenterIndex,
                                     resultShiftTotal:      resultShiftTotal,
                                     shiftDelta:            shiftDelta)
}

func adjustShiftTotalDebug(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int) -> String {
    let data  = adjustShiftTotalDebugData(viewSize: viewSize,
                                          cellSize: cellSize,
                                          cellIncrement: cellIncrement,
                                          shiftTotal: shiftTotal)
    return "vc: \(String(format: "%*.2f", 5, data.viewCenter)) " +
           "vca: \(String(format: "%*.2f", 5, data.viewCenterAdjusted)) " +
           "cc: \(String(format: "%*.2f", 5, data.cellCenter)) " +
           "\(data.cellCenterIndex.rpad(5)) " +
           "\(data.resultCellCenterIndex.rpad(5)) " +
           "shd: \(String(format: "%*.2f", 5, data.shiftDelta)) " +
           "sht: \(String(format: "%3d", data.resultShiftTotal))"
}

func adjustShiftTotalOriginal(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int) -> Int {
    let viewCenter: Double = Double(viewSize) * viewAnchorFactor
    let round: (Double) -> Double = cellIncrement > 0 ? (cellSize % 2 == 0 ? ceil : floor)
                                                      : (cellSize % 2 == 0 ? floor : ceil)
    let cellCenter: Int = Int(round((viewCenter - Double(shiftTotal)) / Double(cellSize)))
    return shiftTotal - (cellCenter * cellIncrement)
}

func test(vs viewSize: Int, cs cellSize: Int, ci cellIncrement: Int, sht shiftTotal: Int,
          expect: AdjustShiftTotalData.Expect? = nil, f: AdjustShiftTotal? = nil) {

    func modulo(_ value: Int, _ modulus: Int) -> Int {
        let remainder: Int = value % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }

    func shiftOpposite(cellSize: Int, shiftX: Int, viewSizeExtra: Int) -> Int {
        return modulo(cellSize + shiftX - viewSizeExtra, cellSize)
    }

    let f: AdjustShiftTotal = f ?? AdjustShiftTotal.DEFAULT
    let newShiftTotal: Int = f.function(viewSize, cellSize, cellIncrement, shiftTotal)
    let newShiftDelta: Int = shiftTotal - newShiftTotal
    let debugInfo: String = f.debug?(viewSize, cellSize, cellIncrement, shiftTotal) ?? ""
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
        if (nchecks > 0) { result = okay ? "✓ OK" : "✗   " } else { result = "?   " }
    }
    print((f.name + ">").padding(toLength: 12, withPad: " ", startingAt: 0) +
          "vs: \(String(format: "%3d", viewSize))  " +
          "cs: \(String(format: "%3d", cellSize)) " +
          "[\(String(format: "%2+d", cellIncrement))]  " +
          "sht: \(String(format: "%4d", shiftTotal))  >>>  " +
          "cs: \(String(format: "%3d", newCellSize))  " +
       // "vse: \(String(format: "%3d", newViewSizeExtra))  " +
          "shd: \(String(format: "%4d", newShiftDelta))  " +
          "sht: \(String(format: "%4d", newShiftTotal))  " +
          "shc: \(String(format: "%3d", newShiftCell))  " +
          "sh: \(String(format: "%3d", newShift))  " +
          "sho: \(newShiftOppositeTest ? String(format: "%2d-", newShiftOpposite!) : " -  ")" +
          (newShiftOppositeTest ? (newShiftOppositeEven! ? "E" : "U") : "") +
          ((expect != nil) ? "  \(result)" : "") +
          ((debugInfo != "") ? " DEB> \(debugInfo)" : "")
    )
}

func test(_ data: [AdjustShiftTotalData], f: AdjustShiftTotal? = nil) {
    let f: AdjustShiftTotal = f ?? AdjustShiftTotal.DEFAULT
    print()
    for item in data {
        test(vs: item.viewSize, cs: item.cellSize, ci: item.cellIncrement, sht: item.shiftTotal, expect: item.expect, f: f)
    }
}


typealias Data = AdjustShiftTotalData

let dataIncOne: [Data] =  [
    Data(vs: 20, cs: 5, ci: 1, sht:   0, expect: (sht: -2,  sh: -2,  sho: 2), confirmed: true),
    Data(vs: 20, cs: 5, ci: 1, sht:  -1, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht:  -2, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht:  -3, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht:  -4, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht:  -5, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht:  -6, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht:  -7, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht:  -8, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht:  -9, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht: -10, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht: -11, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht: -12, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht: -13, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht: -14, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht: -15, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht: -16, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 1, sht: -17, expect: (sht: nil, sh: nil, sho: 0), confirmed: false)
]

let dataIncTwo: [Data] =  [
    Data(vs: 20, cs: 5, ci: 2, sht:   0, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht:  -1, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht:  -2, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht:  -3, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht:  -4, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht:  -5, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht:  -6, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht:  -7, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht:  -8, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht:  -9, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht: -10, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht: -11, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht: -12, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht: -13, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht: -14, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht: -15, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht: -16, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    Data(vs: 20, cs: 5, ci: 2, sht: -17, expect: (sht: nil, sh: nil, sho: 0), confirmed: false)
]

let dataViewSize17: [Data] =  [
    Data(vs: 17, cs: 5, ci: 1, sht:   0, expect: (sht: nil, sh: nil, sho: nil), confirmed: false),
    Data(vs: 17, cs: 5, ci: 8, sht:  -1, expect: (sht: nil, sh: nil, sho: nil), confirmed: false),
]


let dataShiftTotalPositive: [Data] =  [
    Data(vs: 20, cs: 5, ci: 2, sht:   1, expect: (sht: nil, sh: nil, sho: nil), confirmed: false)
]

test(dataIncOne, f: AdjustShiftTotal.DEFAULT)
test(dataIncTwo, f: AdjustShiftTotal.DEFAULT)
// test(dataViewSize17, f: AdjustShiftTotal.DEFAULT)
test(dataShiftTotalPositive, f: AdjustShiftTotal.DEFAULT)
