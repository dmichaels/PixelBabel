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

extension BinaryFloatingPoint {
    func rounded(_ places: Int) -> Self {
        guard places >= 0 else { return self }
        let multiplier = Self(pow(10.0, Double(places)))
        return (self * multiplier).rounded() / multiplier
    }
}

func modulo(_ value: Int, _ modulus: Int) -> Int {
    let remainder: Int = value % modulus
    return remainder >= 0 ? remainder : remainder + modulus
}

let viewAnchorFactor: Double = 0.5

struct AdjustShiftTotalTestData {
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

struct AdjustShiftTotalAlgorithm {
    typealias Function = (Int, Int, Int, Int) -> Int
    typealias DebugFunction = (Int, Int, Int, Int) -> Void
    public let function: Function
    public let name: String
    public let debug: DebugFunction?
    init(_ name: String, _ function: @escaping Function, debug: DebugFunction?) {
        self.function = function
        self.name = name
        self.debug = debug
    }
    public static let DEFAULT:  AdjustShiftTotalAlgorithm = AdjustShiftTotalAlgorithm("DEFAULT",  adjustShiftTotal,
                                                                                      debug: adjustShiftTotalDebug)
    public static let ORIGINAL: AdjustShiftTotalAlgorithm = AdjustShiftTotalAlgorithm("ORIGINAL", adjustShiftTotal,
                                                                                      debug: nil)
}

func adjustShiftTotal(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int) -> Int {
    let viewCenter:         Double = Double(viewSize) * viewAnchorFactor
    let viewCenterAdjusted: Double = viewCenter - Double(shiftTotal)
    let cellCenter:         Double = viewCenterAdjusted / Double(cellSize)
    let shiftDelta:         Double = cellCenter * Double(cellSize + cellIncrement) - viewCenterAdjusted
    return Int(round(Double(shiftTotal) - shiftDelta))
}

func adjustShiftTotalDebug(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int) {

    struct DebugData {

        public let viewSize: Int
        public let cellSize: Int
        public let cellIncrement: Int
        public let shiftTotal: Int

        public var shiftCell: Int { self.shiftTotal / self.cellSize }
        public var shift: Int { self.shiftTotal % self.cellSize }

        public let viewCenter: Double
        public let viewCenterAdjusted: Double
        public let cellCenter: Double
        public let cellCenterIndex: String

        public let cellSizeResult: Int
        public let cellCenterIndexResult: String
        public let shiftTotalResult: Int
        public var shiftCellResult: Int { self.shiftTotalResult / self.cellSizeResult }
        public var shiftResult: Int { self.shiftTotalResult % self.cellSizeResult }
        public let shiftDelta: Double

        public var shiftOppositeResult: Int? {
            guard ((self.shiftTotal % self.cellSize) == 0) && (self.cellCenter == Double(Int(self.cellCenter))) else {
                return nil
            }
            let viewSizeExtraResult: Int = self.viewSize % self.cellSizeResult
            return modulo(self.cellSizeResult + (self.shiftTotalResult % self.cellSizeResult) - viewSizeExtraResult,
                          self.cellSizeResult)
        }
    }

    func debugData(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int) -> DebugData {

        func cellCenterIndex(_ cellCenter: Double, _ cellSize: Int) -> String {
            let cellIndex: Int = Int(cellCenter)
            let cellIndexOffset: Double = (cellCenter - Double(cellIndex)) * Double(cellSize)
            let cellIndexOffsetRounded: Double = cellIndexOffset.rounded(2)
            let cellIndexOffsetEven = cellIndexOffsetRounded == Double(Int(cellIndexOffset))
            return "\(cellIndex)#" +
                   "\(cellIndexOffsetEven ? String(Int(cellIndexOffset)) : String(format: "%.1f", cellIndexOffset))"
        }

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
        let viewCenter:         Double = Double(viewSize) * viewAnchorFactor
        let viewCenterAdjusted: Double = viewCenter - Double(shiftTotal)
        let cellCenter:         Double = viewCenterAdjusted / Double(cellSize)
        let shiftDelta:         Double = cellCenter * Double(cellSize + cellIncrement) - viewCenterAdjusted
        let shiftTotalResult:   Int    = Int(round(Double(shiftTotal) - shiftDelta))

        guard shiftTotalResult == adjustShiftTotal(viewSize: viewSize, cellSize: cellSize,
                                                   cellIncrement: cellIncrement, shiftTotal: shiftTotal) else {
            fatalError("TESTING ERROR")
        }

        return DebugData(viewSize:              viewSize,
                         cellSize:              cellSize,
                         cellIncrement:         cellIncrement,
                         shiftTotal:            shiftTotal,
                         viewCenter:            viewCenter,
                         viewCenterAdjusted:    viewCenterAdjusted,
                         cellCenter:            cellCenter,
                         cellCenterIndex:       cellCenterIndex(cellCenter, cellSize),
                         cellSizeResult:        cellSize + cellIncrement,
                         cellCenterIndexResult: cellCenterIndex(cellCenter, cellSize + cellIncrement),
                         shiftTotalResult:      shiftTotalResult,
                         shiftDelta:            shiftDelta)
    }

    if ((viewSize == 0) && (cellSize == 0) && (cellIncrement == 0) && (shiftTotal == 0)) {
        print(
            " \("vs".lpad(5))" +
            " \("vc".lpad(7))" +
            " \("vca".lpad(7))" +
            " \("cs".lpad(4))" +
            " \("ci".lpad(4))" +
            " \("cc".lpad(5))" +
            "  \("cci".rpad(6))" +
            " \("sht".lpad(5))" +
            " \("shc".lpad(4))" +
            " \("sh".lpad(4))" +
            "   >>>" +
            " \("cs".lpad(4))" +
            "  \("cci".rpad(6))" +
            " \("shd".lpad(5))" +
            " \("sht".lpad(5))" +
            " \("shc".lpad(4))" +
            " \("sh".lpad(4))" +
            " \("sho".lpad(4))" +
        "")
        print(
            " \("==".lpad(5))" +
            " \("--".lpad(7))" +
            " \("---".lpad(7))" +
            " \("==".lpad(4))" +
            " \("==".lpad(4))" +
            " \("--".lpad(5))" +
            "  \("---".rpad(6))" +
            " \("===".lpad(5))" +
            " \("---".lpad(4))" +
            " \("---".lpad(4))" +
            " \("  >>>")" +
            " \("--".lpad(4))" +
            "  \("---".rpad(6))" +
            " \("---".lpad(5))" +
            " \("===".lpad(5))" +
            " \("---".lpad(4))" +
            " \("--".lpad(4))" +
            " \("--".lpad(4))" +
        "")
        return
    }

    let data  = debugData(viewSize: viewSize, cellSize: cellSize, cellIncrement: cellIncrement, shiftTotal: shiftTotal)

    print(
        " \(String(data.viewSize).lpad(5))" +
        " \(String(format: "%.1f", data.viewCenter).lpad(7))" +
        " \(String(format: "%.1f", data.viewCenterAdjusted).lpad(7))" +
        " \(String(data.cellSize).lpad(4))" +
        " \(String(format: "%+d", data.cellIncrement).lpad(4))" +
        " \(String(format: "%.1f", data.cellCenter).lpad(5))" +
        "  \(data.cellCenterIndex.rpad(6))" +
        " \(String(data.shiftTotal).lpad(5))" +
        " \(String(data.shiftCell).lpad(4))" +
        " \(String(data.shift).lpad(4))" +
        "   >>>" +
        " \(String(format: "%4d", data.cellSizeResult))" +
        "  \(data.cellCenterIndexResult.rpad(6))" +
        " \(String(format: "%.1f", data.shiftDelta).lpad(5))" +
        " \(String(data.shiftTotalResult).lpad(5))" +
        " \(String(data.shiftCellResult).lpad(4))" +
        " \(String(data.shiftResult).lpad(4))" +
        " \((data.shiftOppositeResult != nil ? String(data.shiftOppositeResult!) : "-").lpad(4))" +
        (data.shiftOppositeResult != nil ? (data.shiftOppositeResult == abs(data.shiftResult) ? " ✓" : " ✗") : "") +
    "")
}

func adjustShiftTotalOriginal(viewSize: Int, cellSize: Int, cellIncrement: Int, shiftTotal: Int) -> Int {
    let viewCenter: Double = Double(viewSize) * viewAnchorFactor
    let round: (Double) -> Double = cellIncrement > 0 ? (cellSize % 2 == 0 ? ceil : floor)
                                                      : (cellSize % 2 == 0 ? floor : ceil)
    let cellCenter: Int = Int(round((viewCenter - Double(shiftTotal)) / Double(cellSize)))
    return shiftTotal - (cellCenter * cellIncrement)
}

func test(vs viewSize: Int, cs cellSize: Int, ci cellIncrement: Int, sht shiftTotal: Int,
          expect: AdjustShiftTotalTestData.Expect? = nil, f: AdjustShiftTotalAlgorithm? = nil) {

    func shiftOpposite(cellSize: Int, shiftX: Int, viewSizeExtra: Int) -> Int {
        return modulo(cellSize + shiftX - viewSizeExtra, cellSize)
    }

    let f: AdjustShiftTotalAlgorithm = f ?? AdjustShiftTotalAlgorithm.DEFAULT

    let newShiftTotal: Int = f.function(viewSize, cellSize, cellIncrement, shiftTotal)
    let newShiftDelta: Int = shiftTotal - newShiftTotal
    let newCellSize: Int = cellSize + cellIncrement
    let newShiftCell: Int = newShiftTotal / newCellSize
    let newShift: Int = newShiftTotal % newCellSize
    let newViewSizeExtra: Int = viewSize % newCellSize

    let viewCenter:               Double = Double(viewSize) * viewAnchorFactor
    let viewCenterAdjusted:       Double = viewCenter - Double(shiftTotal)
    let cellCenter:               Double = (viewCenterAdjusted) / Double(cellSize)
    let newShiftOppositeRelevant: Bool = ((shiftTotal % cellSize) == 0) && (cellCenter == Double(Int(cellCenter)))

    let newShiftOppositeTest: Bool = (expect != nil) && (expect!.sho != nil) && newShiftOppositeRelevant
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
        if ((expect!.sho != nil) && (newShiftOpposite != nil)) {
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
          "shd: \(String(format: "%4d", newShiftDelta))  " +
          "sht: \(String(format: "%4d", newShiftTotal))  " +
          "shc: \(String(format: "%3d", newShiftCell))  " +
          "sh: \(String(format: "%3d", newShift))  " +
          "sho: \(newShiftOppositeTest ? String(format: "%2d-", newShiftOpposite!) : " -  ")" +
          (newShiftOppositeTest ? (newShiftOppositeEven! ? "E" : "U") : "") +
          ((expect != nil) ? "  \(result)" : "")
    )
}

func test(_ data: [AdjustShiftTotalTestData], f: AdjustShiftTotalAlgorithm? = nil) {
    let f: AdjustShiftTotalAlgorithm = f ?? AdjustShiftTotalAlgorithm.DEFAULT
    print()
    for item in data {
        test(vs: item.viewSize, cs: item.cellSize, ci: item.cellIncrement, sht: item.shiftTotal, expect: item.expect, f: f)
    }
}

func debug(_ data: [AdjustShiftTotalTestData], f: AdjustShiftTotalAlgorithm? = nil) {
    let f: AdjustShiftTotalAlgorithm = f ?? AdjustShiftTotalAlgorithm.DEFAULT
    if let debug = f.debug {
        print()
        debug(0, 0, 0, 0)
        for item in data {
            debug(item.viewSize, item.cellSize, item.cellIncrement, item.shiftTotal)
        }
    }
}

let dataIncOne: [AdjustShiftTotalTestData] =  [
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht:   0, expect: (sht: -2,  sh: -2,  sho: 2), confirmed: true),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht:  -1, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht:  -2, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht:  -3, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht:  -4, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht:  -5, expect: (sht: nil, sh: nil, sho: 2), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht:  -6, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht:  -7, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht:  -8, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht:  -9, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht: -10, expect: (sht: nil, sh: nil, sho: 2), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht: -11, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht: -12, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht: -13, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht: -14, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht: -15, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht: -16, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht: -17, expect: (sht: nil, sh: nil, sho: 0), confirmed: false)
]

let dataIncTwo: [AdjustShiftTotalTestData] =  [
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht:   0, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht:  -1, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht:  -2, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht:  -3, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht:  -4, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht:  -5, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht:  -6, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht:  -7, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht:  -8, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht:  -9, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht: -10, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht: -11, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht: -12, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht: -13, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht: -14, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht: -15, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht: -16, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht: -17, expect: (sht: nil, sh: nil, sho: 0), confirmed: false)
]

let dataViewSize17: [AdjustShiftTotalTestData] =  [
    AdjustShiftTotalTestData(vs: 17, cs: 5, ci: 1, sht:   0, expect: (sht: nil, sh: nil, sho: nil), confirmed: false),
    AdjustShiftTotalTestData(vs: 17, cs: 5, ci: 8, sht:  -1, expect: (sht: nil, sh: nil, sho: nil), confirmed: false),
]


let dataShiftTotalPositive: [AdjustShiftTotalTestData] =  [
    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 2, sht:   1, expect: (sht: nil, sh: nil, sho: nil), confirmed: false)
]

test(dataIncOne, f: AdjustShiftTotalAlgorithm.DEFAULT)
test(dataIncTwo, f: AdjustShiftTotalAlgorithm.DEFAULT)
test(dataViewSize17, f: AdjustShiftTotalAlgorithm.DEFAULT)
test(dataShiftTotalPositive, f: AdjustShiftTotalAlgorithm.DEFAULT)

debug(dataIncOne, f: AdjustShiftTotalAlgorithm.DEFAULT)
debug(dataIncTwo, f: AdjustShiftTotalAlgorithm.DEFAULT)

//  vs      vc     vca   cs   ci    cc  cci      sht  shc   sh   >>>   cs  cci      shd   sht  shc   sh  sho
//  ==      --     ---   ==   ==    --  ---      ===  ---  ---   >>>   --  ---      ---   ===  ---   --   --
//  20    10.0    10.0    5   +1   2.0  2#0        0    0    0   >>>    6  2#0      2.0    -2    0   -2    2
//  20    10.0    11.0    5   +1   2.2  2#1       -1    0   -1   >>>    6  2#1.2    2.2    -3    0   -3    -
//  20    10.0    12.0    5   +1   2.4  2#2.0     -2    0   -2   >>>    6  2#2.4    2.4    -4    0   -4    -
//  20    10.0    13.0    5   +1   2.6  2#3       -3    0   -3   >>>    6  2#3.6    2.6    -6   -1    0    -
//  20    10.0    14.0    5   +1   2.8  2#4.0     -4    0   -4   >>>    6  2#4.8    2.8    -7   -1   -1    -
//  20    10.0    15.0    5   +1   3.0  3#0       -5   -1    0   >>>    6  3#0      3.0    -8   -1   -2    2
//  20    10.0    16.0    5   +1   3.2  3#1       -6   -1   -1   >>>    6  3#1.2    3.2    -9   -1   -3    -
//  20    10.0    17.0    5   +1   3.4  3#2.0     -7   -1   -2   >>>    6  3#2.4    3.4   -10   -1   -4    -
//  20    10.0    18.0    5   +1   3.6  3#3       -8   -1   -3   >>>    6  3#3.6    3.6   -12   -2    0    -
//  20    10.0    19.0    5   +1   3.8  3#4.0     -9   -1   -4   >>>    6  3#4.8    3.8   -13   -2   -1    -
//  20    10.0    20.0    5   +1   4.0  4#0      -10   -2    0   >>>    6  4#0      4.0   -14   -2   -2    2
//  20    10.0    21.0    5   +1   4.2  4#1      -11   -2   -1   >>>    6  4#1.2    4.2   -15   -2   -3    -
//  20    10.0    22.0    5   +1   4.4  4#2      -12   -2   -2   >>>    6  4#2.4    4.4   -16   -2   -4    -
//  20    10.0    23.0    5   +1   4.6  4#3.0    -13   -2   -3   >>>    6  4#3.6    4.6   -18   -3    0    -
//  20    10.0    24.0    5   +1   4.8  4#4.0    -14   -2   -4   >>>    6  4#4.8    4.8   -19   -3   -1    -
//  20    10.0    25.0    5   +1   5.0  5#0      -15   -3    0   >>>    6  5#0      5.0   -20   -3   -2    2
//  20    10.0    26.0    5   +1   5.2  5#1      -16   -3   -1   >>>    6  5#1.2    5.2   -21   -3   -3    -
//  20    10.0    27.0    5   +1   5.4  5#2      -17   -3   -2   >>>    6  5#2.4    5.4   -22   -3   -4    -
//
//  vs      vc     vca   cs   ci    cc  cci      sht  shc   sh   >>>   cs  cci      shd   sht  shc   sh  sho
//  ==      --     ---   ==   ==    --  ---      ===  ---  ---   >>>   --  ---      ---   ===  ---   --   --
//  20    10.0    10.0    5   +2   2.0  2#0        0    0    0   >>>    7  2#0      4.0    -4    0   -4    4
//  20    10.0    11.0    5   +2   2.2  2#1       -1    0   -1   >>>    7  2#1.4    4.4    -5    0   -5    -
//  20    10.0    12.0    5   +2   2.4  2#2.0     -2    0   -2   >>>    7  2#2.8    4.8    -7   -1    0    -
//  20    10.0    13.0    5   +2   2.6  2#3       -3    0   -3   >>>    7  2#4.2    5.2    -8   -1   -1    -
//  20    10.0    14.0    5   +2   2.8  2#4.0     -4    0   -4   >>>    7  2#5.6    5.6   -10   -1   -3    -
//  20    10.0    15.0    5   +2   3.0  3#0       -5   -1    0   >>>    7  3#0      6.0   -11   -1   -4    4
//  20    10.0    16.0    5   +2   3.2  3#1       -6   -1   -1   >>>    7  3#1.4    6.4   -12   -1   -5    -
//  20    10.0    17.0    5   +2   3.4  3#2.0     -7   -1   -2   >>>    7  3#2.8    6.8   -14   -2    0    -
//  20    10.0    18.0    5   +2   3.6  3#3       -8   -1   -3   >>>    7  3#4.2    7.2   -15   -2   -1    -
//  20    10.0    19.0    5   +2   3.8  3#4.0     -9   -1   -4   >>>    7  3#5.6    7.6   -17   -2   -3    -
//  20    10.0    20.0    5   +2   4.0  4#0      -10   -2    0   >>>    7  4#0      8.0   -18   -2   -4    4
//  20    10.0    21.0    5   +2   4.2  4#1      -11   -2   -1   >>>    7  4#1.4    8.4   -19   -2   -5    -
//  20    10.0    22.0    5   +2   4.4  4#2      -12   -2   -2   >>>    7  4#2.8    8.8   -21   -3    0    -
//  20    10.0    23.0    5   +2   4.6  4#3.0    -13   -2   -3   >>>    7  4#4.2    9.2   -22   -3   -1    -
//  20    10.0    24.0    5   +2   4.8  4#4.0    -14   -2   -4   >>>    7  4#5.6    9.6   -24   -3   -3    -
//  20    10.0    25.0    5   +2   5.0  5#0      -15   -3    0   >>>    7  5#0     10.0   -25   -3   -4    4
//  20    10.0    26.0    5   +2   5.2  5#1      -16   -3   -1   >>>    7  5#1.4   10.4   -26   -3   -5    -
//  20    10.0    27.0    5   +2   5.4  5#2      -17   -3   -2   >>>    7  5#2.8   10.8   -28   -4    0    -
