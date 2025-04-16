import Foundation

struct Memory
{
    static let bufferBlockSize: Int = 4

    // Copies (fast) the given (UInt32) value to the given (UInt8 array) buffer starting
    // at the given byte index, successively up to the given count times, into the buffer.
    // Note the units: The buffer is bytes; the index is in bytes; the count refers to the
    // number 4-byte (UInt32 - not byte) values; and value is a 4-byte (UInt32) value.
    //
    static func fastcopy(to buffer: inout [UInt8], index: Int, count: Int, value: UInt32) {
        let byteIndex = index
        let byteCount = count * Memory.bufferBlockSize
        guard byteIndex >= 0, byteIndex + byteCount <= buffer.count else {
            //
            // Out of bounds.
            //
            return
        }
        var rvalue = value.bigEndian
        buffer.withUnsafeMutableBytes { dest in
            let base = dest.baseAddress!.advanced(by: byteIndex)
            for offset in stride(from: 0, to: byteCount, by: Memory.bufferBlockSize) {
                memcpy(base + offset, &rvalue, Memory.bufferBlockSize)
            }
        }
    }

    // Same as above except the caller passes in the unsafe mutable byte-array buffer.
    //
    static func fastcopy(to base: UnsafeMutableRawPointer, count: Int, value: UInt32) {
        let byteCount = count * Memory.bufferBlockSize
        var rvalue = value.bigEndian
        for offset in stride(from: 0, to: byteCount, by: Memory.bufferBlockSize) {
            memcpy(base + offset, &rvalue, Memory.bufferBlockSize)
        }
    }
}
