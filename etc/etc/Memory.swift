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
            // Out of bounds
            //
            return
        }
        var rvalue = value.bigEndian
        buffer.withUnsafeMutableBytes { raw in
            let base = raw.baseAddress!.advanced(by: byteIndex)
            switch count {
            case 1:
                base.storeBytes(of: rvalue, as: UInt32.self)
            case 2:
                base.storeBytes(of: rvalue, as: UInt32.self)
                (base + Memory.bufferBlockSize).storeBytes(of: rvalue, as: UInt32.self)
            default:
                memset_pattern4(base, &rvalue, byteCount)
            }
        }
    }

    // Same as above except the caller passes in the unsafe mutable byte-array buffer,
    // and thus the index will not need to be passed; usage would be like this:
    //
    //     buffer.withUnsafeMutableBytes { raw in
    //         let base: UnsafeMutableRawPointer = raw.baseAddress!.advanced(by: your_index)
    //         Memory.fastcopy(to: base, count: your_count, value: your_value)
    //     }
    //
    static func fastcopy(to base: UnsafeMutableRawPointer, count: Int, value: UInt32) {
        var rvalue = value.bigEndian
        switch count {
        case 1:
            base.storeBytes(of: rvalue, as: UInt32.self)
        case 2:
            base.storeBytes(of: rvalue, as: UInt32.self)
            (base + Memory.bufferBlockSize).storeBytes(of: rvalue, as: UInt32.self)
        default:
            memset_pattern4(base, &rvalue, count * Memory.bufferBlockSize)
        }
    }

    // OLDER/SLOWER VERSIONS ...

    static func xfastcopy(to buffer: inout [UInt8], index: Int, count: Int, value: UInt32) {
        let byteIndex = index
        let byteCount = count * Memory.bufferBlockSize
        guard byteIndex >= 0, byteIndex + byteCount <= buffer.count else {
            //
            // Out of bounds.
            //
            return
        }
        var rvalue: UInt32 = value.bigEndian
        buffer.withUnsafeMutableBytes { dest in
            let base = dest.baseAddress!.advanced(by: byteIndex)
            for offset in stride(from: 0, to: byteCount, by: Memory.bufferBlockSize) {
                memcpy(base + offset, &rvalue, Memory.bufferBlockSize)
            }
        }
    }

    static func xfastcopy(to base: UnsafeMutableRawPointer, count: Int, value: UInt32) {
        let byteCount = count * Memory.bufferBlockSize
        var rvalue: UInt32 = value.bigEndian
        for offset in stride(from: 0, to: byteCount, by: Memory.bufferBlockSize) {
            memcpy(base + offset, &rvalue, Memory.bufferBlockSize)
        }
    }

    static func yfastcopy(to buffer: inout [UInt8], index: Int, count: Int, value: UInt32) {
        let byteIndex = index
        let byteCount = count * Memory.bufferBlockSize
        guard byteIndex >= 0, byteIndex + byteCount <= buffer.count else {
            return
        }
        buffer.withUnsafeMutableBytes { raw in
            let typedPtr = raw.baseAddress!.advanced(by: byteIndex).assumingMemoryBound(to: UInt32.self)
            let rvalue = value.bigEndian
            for i in 0..<count {
                typedPtr[i] = rvalue
            }
        }
    }
}
