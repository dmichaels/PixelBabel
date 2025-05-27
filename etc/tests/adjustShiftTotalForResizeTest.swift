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
    let cellSizeIncrement: Int
    let shiftTotal: Int
    let expect: Expect?
    let confirmed: Bool
    let debug: Bool
    init(vs viewSize: Int, cs cellSize: Int, ci cellSizeIncrement: Int, sht shiftTotal: Int,
         expect: Expect?, confirmed: Bool = false, debug: Bool = false) {
        self.viewSize = viewSize
        self.cellSize = cellSize
        self.cellSizeIncrement = cellSizeIncrement
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
}

func adjustShiftTotal(viewSize: Int, cellSize: Int, cellSizeIncrement: Int, shiftTotal: Int) -> Int {
    let viewCenter:          Double = Double(viewSize) * viewAnchorFactor
    let viewCenterAdjusted:  Double = viewCenter - Double(shiftTotal)
    let cellCenter:          Double = viewCenterAdjusted / Double(cellSize)
    let cellSizeIncremented: Int    = cellSize + cellSizeIncrement
    let shiftDelta:          Double = cellCenter * Double(cellSizeIncremented) - viewCenterAdjusted
    let round                       = ((cellSizeIncremented) % 2 == 0) ? ceil : floor
    return Int(round(Double(shiftTotal) - shiftDelta))
}

func adjustShiftTotalDebug(viewSize: Int, cellSize: Int, cellSizeIncrement: Int, shiftTotal: Int) {

    struct DebugData {

        public let viewSize: Int
        public let cellSize: Int
        public let shiftTotal: Int
        public var shiftCell: Int { self.shiftTotal / self.cellSize }
        public var shift: Int { self.shiftTotal % self.cellSize }
        public let viewCenter: Double
        public let viewCenterAdjusted: Double
        public let cellCenter: Double
        public let cellCenterIndex: String

        public let cellSizeIncrement: Int
        public let cellSizeResult: Int
        public let cellCenterIndexResult: String
        public let shiftTotalResult: Int
        public var shiftCellResult: Int { self.shiftTotalResult / self.cellSizeResult }
        public var shiftResult: Int { self.shiftTotalResult % self.cellSizeResult }
        public let shiftDelta: Double

        public var shiftOpposite: Int {
            let viewSizeExtra: Int = self.viewSize % self.cellSize
            return modulo(self.cellSize + self.shift - viewSizeExtra, self.cellSize)
        }

        public var shiftOppositeEven: Bool {
            (self.shift <= 0) ? [0,  1].contains(self.shiftOpposite + self.shift)
                              : [0, -1].contains(self.shiftOpposite - self.shift)
        }

        public var shiftOppositeIndicator: String {
            shiftOppositeEven ? "\(self.shiftOpposite) ✓" : "\(self.shiftOpposite) ✗"
        }

        public var shiftOppositeResult: Int {
            let viewSizeExtraResult: Int = self.viewSize % self.cellSizeResult
            return modulo(self.cellSizeResult + (self.shiftTotalResult % self.cellSizeResult) - viewSizeExtraResult, self.cellSizeResult)
        }

        public var shiftOppositeEvenResult: Bool? {
            //
            // Only return a (non-nil) result if the starting (not result) appeared to be evenly balanced.
            //
            guard self.shiftOppositeEven else { return nil }
            return (self.shiftResult <= 0) ? [0,  1].contains(self.shiftOppositeResult + self.shiftResult)
                                           : [0, -1].contains(self.shiftOppositeResult - self.shiftResult)
        }

        public var shiftOppositeEvenIndicatorResult: String {
            if let shiftOppositeEvenResult = self.shiftOppositeEvenResult {
                return shiftOppositeEvenResult ? "\(self.shiftOppositeResult) ✓" : "\(self.shiftOppositeResult) ✗"
            }
            else {
                return "\(self.shiftOppositeResult) -"
            }
        }
    }

    func debugData(viewSize: Int, cellSize: Int, cellSizeIncrement: Int, shiftTotal: Int) -> DebugData {

        func cellCenterIndex(_ cellCenter: Double, _ cellSize: Int) -> String {
            let cellIndex: Int = Int(cellCenter)
            let cellIndexOffset: Double = ((cellCenter - Double(cellIndex)) * Double(cellSize)).rounded(5)
            let cellIndexOffsetEven = cellIndexOffset == Double(Int(cellIndexOffset))
            return "\(cellIndex)#" +
                   "\(cellIndexOffsetEven ? String(Int(cellIndexOffset)) : String(format: "%.2f", cellIndexOffset))"
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
        // cellSizeIncrement: +2
        // shiftTotal:    -3
        //
        // What this means is that for this example, whereas we'd previously confidently said that resuling shiftTotal,
        // upon resize (from 5 to 7) should be -7 it should actually be -8. Still may be some rounding (floor vs ceil etc)
        // issues with this but this is a crucial distinction we just realized to be the case. Need to manually redo test cases.
        //
        let viewCenter:          Double = Double(viewSize) * viewAnchorFactor
        let viewCenterAdjusted:  Double = viewCenter - Double(shiftTotal)
        let cellCenter:          Double = viewCenterAdjusted / Double(cellSize)
        let cellSizeIncremented: Int    = cellSize + cellSizeIncrement
        let shiftDelta:          Double = cellCenter * Double(cellSizeIncremented) - viewCenterAdjusted
        let round                       = ((cellSizeIncremented) % 2 == 0) ? ceil : floor
        let shiftTotalResult:    Int    = Int(round(Double(shiftTotal) - shiftDelta))

        guard shiftTotalResult == adjustShiftTotal(viewSize: viewSize, cellSize: cellSize,
                                                   cellSizeIncrement: cellSizeIncrement, shiftTotal: shiftTotal) else {
            fatalError("TESTING ERROR")
        }

        return DebugData(viewSize:              viewSize,
                         cellSize:              cellSize,
                         shiftTotal:            shiftTotal,
                         viewCenter:            viewCenter,
                         viewCenterAdjusted:    viewCenterAdjusted,
                         cellCenter:            cellCenter,
                         cellCenterIndex:       cellCenterIndex(cellCenter, cellSize),
                         cellSizeIncrement:     cellSizeIncrement,
                         cellSizeResult:        cellSizeIncremented,
                         cellCenterIndexResult: cellCenterIndex(cellCenter, cellSize + cellSizeIncrement),
                         shiftTotalResult:      shiftTotalResult,
                         shiftDelta:            shiftDelta)
    }

    if ((viewSize == 0) && (cellSize == 0) && (cellSizeIncrement == 0) && (shiftTotal == 0)) {
        print(
            " \("vs".lpad(5))" +
            " \("vc".lpad(7))" +
            " \("vca".lpad(7))" +
            " \("cs".lpad(4))" +
            " \("ci".lpad(4))" +
            " \("cc".lpad(5))" +
            "  \("cci".rpad(7))" +
            " \("sht".lpad(5))" +
            " \("shc".lpad(4))" +
            " \("sh".lpad(4))" +
            " \("sho".lpad(5))" + // <<<<<<<
            "   >>>" +
            " \("cs".lpad(4))" +
            "  \("cci".rpad(7))" +
            " \("shd".lpad(5))" +
            " \("sht".lpad(5))" +
            " \("shc".lpad(4))" +
            " \("sh".lpad(4))" +
            " \("sho".lpad(5))" +
        "")
        print(
            " \("==".lpad(5))" +
            " \("--".lpad(7))" +
            " \("---".lpad(7))" +
            " \("==".lpad(4))" +
            " \("==".lpad(4))" +
            " \("--".lpad(5))" +
            "  \("---".rpad(7))" +
            " \("===".lpad(5))" +
            " \("---".lpad(4))" +
            " \("---".lpad(4))" +
            " \("---".lpad(5))" + // <<<<<<<
            " \("  >>>")" +
            " \("--".lpad(4))" +
            "  \("---".rpad(7))" +
            " \("---".lpad(5))" +
            " \("===".lpad(5))" +
            " \("---".lpad(4))" +
            " \("--".lpad(4))" +
            " \("---".lpad(5))" +
        "")
        return
    }

    let data  = debugData(viewSize: viewSize, cellSize: cellSize, cellSizeIncrement: cellSizeIncrement, shiftTotal: shiftTotal)

    print(
        " \(String(data.viewSize).lpad(5))" +
        " \(String(format: "%.2f", data.viewCenter).lpad(7))" +
        " \(String(format: "%.2f", data.viewCenterAdjusted).lpad(7))" +
        " \(String(data.cellSize).lpad(4))" +
        " \(String(format: "%+d", data.cellSizeIncrement).lpad(4))" +
        " \(String(format: "%.2f", data.cellCenter).lpad(5))" +
        "  \(data.cellCenterIndex.rpad(7))" +
        " \(String(data.shiftTotal).lpad(5))" +
        " \(String(data.shiftCell).lpad(4))" +
        " \(String(data.shift).lpad(4))" +
        " \(String(data.shiftOppositeIndicator).lpad(5))" +
        "   >>>" +
        " \(String(format: "%4d", data.cellSizeResult))" +
        "  \(data.cellCenterIndexResult.rpad(7))" +
        " \(String(format: "%.2f", data.shiftDelta).lpad(5))" +
        " \(String(data.shiftTotalResult).lpad(5))" +
        " \(String(data.shiftCellResult).lpad(4))" +
        " \(String(data.shiftResult).lpad(4))" +
        " \(String(data.shiftOppositeEvenIndicatorResult).lpad(5))" +
    "")
}

func debug(_ data: [AdjustShiftTotalTestData], f: AdjustShiftTotalAlgorithm? = nil) {
    let f: AdjustShiftTotalAlgorithm = f ?? AdjustShiftTotalAlgorithm.DEFAULT
    if let debug = f.debug {
        print()
        debug(0, 0, 0, 0)
        for item in data {
            debug(item.viewSize, item.cellSize, item.cellSizeIncrement, item.shiftTotal)
        }
    }
}

debug([
    AdjustShiftTotalTestData(vs: 17, cs: 5, ci: 1, sht:   0, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 17, cs: 6, ci: 1, sht:  -1, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 17, cs: 7, ci: 1, sht:  -3, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 17, cs: 8, ci: 1, sht:  -4, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 17, cs: 9, ci: 1, sht:  -6, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),

    AdjustShiftTotalTestData(vs: 20, cs: 5, ci: 1, sht:   0, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 6, ci: 1, sht:  -2, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 7, ci: 1, sht:  -4, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 8, ci: 1, sht:  -6, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 20, cs: 9, ci: 1, sht:  -8, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
], f: AdjustShiftTotalAlgorithm.DEFAULT)

debug([
    AdjustShiftTotalTestData(vs: 1161, cs: 129, ci:  1, sht:   0, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 130, ci:  1, sht:  -4, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 131, ci:  1, sht:  -9, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 132, ci:  1, sht: -13, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 133, ci:  1, sht: -18, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 134, ci:  1, sht: -22, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 135, ci:  1, sht: -27, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
], f: AdjustShiftTotalAlgorithm.DEFAULT)
