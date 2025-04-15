import Foundation

struct Memory
{
    static func fastcopy(to buffer: inout [UInt8], index: Int, count: Int, value: UInt32) {
        let byteIndex = index * 4
        let byteCount = count * 4
        guard byteIndex >= 0, byteIndex + byteCount <= buffer.count else {
            //
            // Out of bounds.
            //
            return
        }
        var rvalue = value.bigEndian
        buffer.withUnsafeMutableBytes { dest in
            let base = dest.baseAddress!.advanced(by: byteIndex)
            for offset in stride(from: 0, to: byteCount, by: 4) {
                memcpy(base + offset, &rvalue, 4)
            }
        }
    }
}
