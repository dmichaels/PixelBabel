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

        // Returns the adjusted total shift value for the given view size (width or height), cell size and the amount
        // it is being incremented by, and the current total shift value, so that the cells within the view remain
        // centered (where they were at the current/given cell size and shift total values) and after the cell size
        // has been adjusted by the given increment; this is the default behavior, but if a given view anchor factor
        // is specified, then the "center" of the view is taken to be the given view size times this given view anchor
        // factor (this is 0.5 by default giving the default centered behavior). This is only for handling zooming.
        //
        // This is tricky. Turns out it is literally impossible to compute this accurately for increments or more
        // than one without actually going through iteratively and computing the result one increment at a time,
        // due to the cummulative effects of rounding. Another possible solution is to define this function as
        // working properly only for increments of one, and when zooming if this function would otherwise be called
        // with increments greater than one, then manually manufacture zoom "events" for the intermediate steps,
        // i.e. call the resizeCells function iteratively; if we were worried about performance with this iteratively
        // looping solution here, that alternate solution would should be orders of magnitude less performant, but
        // the result might (might) look even smoother, or it could just make things seem slower and sluggish.
        //
        func adjustShiftTotal(viewSize: Int, cellSize: Int, cellSizeIncrement: Int, shiftTotal: Int) -> Int {
            let viewAnchorFactor: Double = 0.5
            let viewCenter: Double = Double(viewSize) * viewAnchorFactor
            var viewCenterAdjusted: Double = viewCenter - Double(shiftTotal)
            var cellSizeResult: Int = cellSize
            var shiftTotalResult: Int = shiftTotal
            let increment: Int = cellSizeIncrement > 0 ? 1 : -1
            for _ in 0..<abs(cellSizeIncrement){
                viewCenterAdjusted = viewCenter - Double(shiftTotalResult)
                let shiftDelta: Double = (viewCenterAdjusted * Double(increment)) / Double(cellSizeResult)
                cellSizeResult += increment
                shiftTotalResult = Int(((cellSizeResult % 2 == 0) ? ceil : floor)(Double(shiftTotalResult) - shiftDelta))
            }
            return shiftTotalResult
        }
        func bug_adjustShiftTotal(viewSize: Int, cellSize: Int, cellSizeIncrement: Int, shiftTotal: Int) -> Int {
            let viewAnchorFactor: Double = 0.5
            let viewCenter: Double = Double(viewSize) * viewAnchorFactor
            let viewCenterAdjusted: Double = viewCenter - Double(shiftTotal)
            var cellSizeResult: Int = cellSize
            var shiftTotalResult: Int = shiftTotal
            let increment: Int = cellSizeIncrement > 0 ? 1 : -1
            for _ in 0..<abs(cellSizeIncrement){
                let shiftDelta: Double = (viewCenterAdjusted * Double(increment)) / Double(cellSizeResult)
                cellSizeResult += increment
                shiftTotalResult = Int(((cellSizeResult % 2 == 0) ? ceil : floor)(Double(shiftTotalResult) - shiftDelta))
            }
            return shiftTotalResult
        }

func save_adjustShiftTotal(viewSize: Int, cellSize: Int, cellSizeIncrement: Int, shiftTotal: Int) -> Int {
    let viewAnchorFactor: Double = 0.5
    let viewCenter:          Double = Double(viewSize) * viewAnchorFactor
    let viewCenterAdjusted:  Double = viewCenter - Double(shiftTotal)
    let cellCenter:          Double = viewCenterAdjusted / Double(cellSize)
    let cellSizeIncremented: Int    = cellSize + cellSizeIncrement
    let shiftDelta:          Double = cellCenter * Double(cellSizeIncremented) - viewCenterAdjusted
    let round                       = ((cellSizeIncremented) % 2 == 0) ? ceil : floor
    return Int(round(Double(shiftTotal) - shiftDelta))
}

func adjustShiftTotalSAVE(viewSize: Int, cellSize: Int, cellSizeIncrement: Int, shiftTotal: Int) -> Int {
    let viewAnchorFactor: Double = 0.5
    let viewCenter: Double          = Double(viewSize) * viewAnchorFactor
    let viewCenterAdjusted: Double  = viewCenter - Double(shiftTotal)
    let cellSizeIncremented: Int    = cellSize + cellSizeIncrement
    let round: (Double) -> Double   = ((cellSizeIncremented) % 2 == 0) ? ceil : floor
    //
    // This is the original calculation for shiftDelta:
    //
    //   let cellCenter:          Double = viewCenterAdjusted / Double(cellSize)
    //   let shiftDelta:          Double = cellCenter * Double(cellSizeIncremented) - viewCenterAdjusted
    //   let round                       = ((cellSizeIncremented) % 2 == 0) ? ceil : floor
    //
    // which can be simplified to this:
    //
    //   let shiftDelta:          Double = ((viewCenter - Double(shiftTotal)) * cellSizeIncrement) / cellSize
    //   let round                       = ((cellSize + cellSizeIncrement) % 2 == 0) ? ceil : floor
    //
    let shiftDelta: Double          = (viewCenterAdjusted * Double(cellSizeIncrement)) / Double(cellSize)
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
        public var shiftDeltaRaw: Double { cellCenter * Double(cellSizeResult) }
        public var shiftDeltaRaw2: Double { cellCenter * Double(cellSize) }

        public var shiftOpposite: Int {
            let viewSizeExtra: Int = self.viewSize % self.cellSize
            return modulo(self.cellSize + self.shift - viewSizeExtra, self.cellSize)
        }

        public var shiftOppositeEven: Bool {
            (self.shift <= 0) ? [0,  1].contains(self.shiftOpposite + self.shift)
                              : [0, -1].contains(self.shiftOpposite - self.shift)
        }

        public var shiftOppositeIndicator: String {
            shiftOppositeEven ? "✓ \(self.shiftOpposite)" : "✗ \(self.shiftOpposite)"
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
                return shiftOppositeEvenResult ? "✓ \(self.shiftOppositeResult)" : "✗ \(self.shiftOppositeResult)"
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
/*
        let viewCenter:          Double = Double(viewSize) * viewAnchorFactor
        let viewCenterAdjusted:  Double = viewCenter - Double(shiftTotal)
        let cellCenter:          Double = viewCenterAdjusted / Double(cellSize)
        let cellSizeIncremented: Int    = cellSize + cellSizeIncrement
        let round                       = (cellSizeIncremented % 2 == 0) ? ceil : floor
        let shiftDelta:          Double = (viewCenterAdjusted * Double(cellSizeIncrement)) / Double(cellSize)
        let shiftTotalResult:    Int    = Int(round(Double(shiftTotal) - shiftDelta))
*/

        /*
        let viewAnchorFactor: Double = 0.5
        let viewCenter: Double = Double(viewSize) * viewAnchorFactor
        let viewCenterAdjusted: Double = viewCenter - Double(shiftTotal)
        var cellSizeResult: Int = cellSize
        var cellCenter: Double = 0.0
        var shiftDelta: Double = 0.0
        var shiftTotalResult: Int = shiftTotal
        let increment: Int = cellSizeIncrement > 0 ? 1 : -1
        for _ in 0..<abs(cellSizeIncrement){
            cellCenter = viewCenterAdjusted / Double(cellSizeResult)
            shiftDelta = (viewCenterAdjusted * Double(increment)) / Double(cellSizeResult)
            cellSizeResult += increment
            shiftTotalResult = Int(((cellSizeResult % 2 == 0) ? ceil : floor)(Double(shiftTotalResult) - shiftDelta))
            print("LOOP: \(shiftTotalResult)")
        }
        */
        let viewAnchorFactor: Double = 0.5
        let viewCenter: Double = Double(viewSize) * viewAnchorFactor
        var viewCenterAdjusted: Double = 0.0
        var cellSizeResult: Int = cellSize
        var cellCenter: Double = 0.0
        var shiftDelta: Double = 0.0
        var shiftTotalResult: Int = shiftTotal
        let increment: Int = cellSizeIncrement > 0 ? 1 : -1
        for _ in 0..<abs(cellSizeIncrement){
            viewCenterAdjusted = viewCenter - Double(shiftTotalResult)
            cellCenter = viewCenterAdjusted / Double(cellSizeResult)
            shiftDelta = (viewCenterAdjusted * Double(increment)) / Double(cellSizeResult)
            cellSizeResult += increment
            shiftTotalResult = Int(((cellSizeResult % 2 == 0) ? ceil : floor)(Double(shiftTotalResult) - shiftDelta))
            // print("LOOP: \(shiftTotalResult)")
        }

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
                         cellSizeResult:        cellSize + cellSizeIncrement,
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
            "  \("cci".rpad(8))" +
            " \("sht".lpad(5))" +
            " \("shc".lpad(4))" +
            " \("sh".lpad(4))" +
            " \("sho".lpad(5))" + // <<<<<<<
            "   >>>" +
            " \("cs".lpad(4))" +
            "  \("cci".rpad(8))" +
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
            "  \("---".rpad(8))" +
            " \("===".lpad(5))" +
            " \("---".lpad(4))" +
            " \("---".lpad(4))" +
            " \("---".lpad(5))" + // <<<<<<<
            " \("  >>>")" +
            " \("--".lpad(4))" +
            "  \("---".rpad(8))" +
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
        "  \(data.cellCenterIndex.rpad(8))" +
        " \(String(data.shiftTotal).lpad(5))" +
        " \(String(data.shiftCell).lpad(4))" +
        " \(String(data.shift).lpad(4))" +
        " \(String(data.shiftOppositeIndicator).lpad(5))" +
        "   >>>" +
        " \(String(format: "%4d", data.cellSizeResult))" +
        "  \(data.cellCenterIndexResult.rpad(8))" +
        // " \(String(format: "%.2f", data.shiftDeltaRaw).lpad(6))" +
        // " \(String(format: "%.2f", data.shiftDeltaRaw2).lpad(6))" +
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
    AdjustShiftTotalTestData(vs: 1161, cs: 129, ci: +1, sht:   0, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 130, ci: +1, sht:  -4, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 131, ci: +1, sht:  -9, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 132, ci: +1, sht: -13, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 133, ci: +1, sht: -18, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 134, ci: +1, sht: -22, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 135, ci: +1, sht: -27, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 136, ci: +1, sht: -31, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 137, ci: +1, sht: -36, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 138, ci: +1, sht: -40, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 139, ci: +1, sht: -45, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 140, ci: +1, sht: -49, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 141, ci: +1, sht: -54, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 142, ci: +1, sht: -58, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 143, ci: +1, sht: -63, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 144, ci: +1, sht: -67, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 145, ci: +1, sht: -72, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 146, ci: +1, sht: -76, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 147, ci: +1, sht: -81, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),

    AdjustShiftTotalTestData(vs: 1161, cs: 140, ci: +4, sht: -49, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 129, ci: 18, sht: 0, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 133, ci: 76, sht: -18, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 148, ci: +1, sht: -85, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 149, ci: +1, sht: -90, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 162, ci: 438, sht: -148, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),

    // Going from 143 to 144 OK but not from 140 to 144

], f: AdjustShiftTotalAlgorithm.DEFAULT)

debug([
    AdjustShiftTotalTestData(vs: 1161, cs: 140, ci: +1, sht: -49, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 141, ci: +1, sht: -54, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 142, ci: +1, sht: -58, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 143, ci: +1, sht: -63, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
    AdjustShiftTotalTestData(vs: 1161, cs: 140, ci: +4, sht: -49, expect: (sht: nil, sh: nil, sho: 0), confirmed: false),
], f: AdjustShiftTotalAlgorithm.DEFAULT)

// SHIFTSC(-292,-639)> 0.01698s vw: [1161] vwe: [116] shc: [-1,-3] sh: [-83,-12] sh-u: [-28,-4] sht: [-292,-639] sht-u: [-98,-214] bm: 21296 cs: 209 cs-u: 70 vc: 5 vce: 1 vcv: 6 vcev: 5 shr: 10 ok: false
// SHIFTSC(-393,-866)> 0.01477s vw: [1161] vwe: [221] shc: [-1,-3] sh: [-158,-161] sh-u: [-53,-54] sht: [-393,-866] sht-u: [-131,-288] bm: 22064 cs: 235 cs-u: 78 vc: 4 vce: 2 vcv: 6 vcev: 5 shr: 91 ok: false
// SHIFTSC(-397,-875)> 0.01362s vw: [1161] vwe: [217] shc: [-1,-3] sh: [-161,-167] sh-u: [-54,-56] sht: [-397,-875] sht-u: [-133,-293] bm: 22400 cs: 236 cs-u: 79 vc: 4 vce: 2 vcv: 6 vcev: 5 shr: 94 ok: false
// adjustShiftTotalDebug(viewSize: 0, cellSize: 0, cellSizeIncrement: 0, shiftTotal:  0)
// adjustShiftTotalDebug(viewSize: 1161, cellSize: 366, cellSizeIncrement: 234, shiftTotal:  -1534)
//    vs      vc     vca   cs   ci    cc  cci        sht  shc   sh   sho   >>>   cs  cci        shd   sht  shc   sh   sho
//    ==      --     ---   ==   ==    --  ---        ===  ---  ---   ---   >>>   --  ---        ---   ===  ---   --   ---
//  1161  580.50 3396.50  366 +234  5.67  5#245.32 -1534   -4  -70 ✗ 233   >>>  600  5#402.17  5.67 -2821   -4 -421 218 -

print()
// SHIFTSC(-2097,-4660)> 0.04316s vw: [1161] vwe: [566] shc: [-3,-7] sh: [-312,-495] sh-u: [-104,-165] sht: [-2097,-4660] sht-u: [-698,-1551] bm: 56816 cs: 595 cs-u: 198 vc: 1 vce: 2 vcv: 3 vcev: 2 shr: 312 ok: true
// MAXOUT
// SHIFTSC(-319,-710)> 0.04476s vw: [1161] vwe: [561] shc: [0,-1] sh: [-319,-110] sh-u: [-106,-37] sht: [-319,-710] sht-u: [-106,-237] bm: 57088 cs: 600 cs-u: 200 vc: 1 vce: 2 vcv: 3 vcev: 2 shr: 320 ok: true
// MAXOUT
// SHIFTSC(281,690)> 0.04478s vw: [1161] vwe: [561] shc: [0,1] sh: [281,90] sh-u: [94,30] sht: [281,690] sht-u: [94,230] bm: 57088 cs: 600 cs-u: 200 vc: 1 vce: 2 vcv: 3 vcev: 1 shr: 320 ok: true <<< NOTOK
// MAXOUT
// SHIFTSC(481,1090)> 0.03454s vw: [1161] vwe: [561] shc: [0,1] sh: [481,490] sh-u: [160,163] sht: [481,1090] sht-u: [160,363] bm: 55680 cs: 600 cs-u: 200 vc: 1 vce: 2 vcv: 3 vcev: 1 shr: 520 ok: false
adjustShiftTotalDebug(viewSize: 0, cellSize: 0, cellSizeIncrement: 0, shiftTotal:  0)
adjustShiftTotalDebug(viewSize: 1161, cellSize: 595, cellSizeIncrement: 5, shiftTotal:  -2097)
adjustShiftTotalDebug(viewSize: 1161, cellSize: 600, cellSizeIncrement: 0, shiftTotal:  -319)
