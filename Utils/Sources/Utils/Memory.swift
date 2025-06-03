import Foundation

public struct Memory
{
    public static let bufferBlockSize: Int = 4

    // Copies (fast) the given (UInt32) value to the given (UInt8 array) buffer starting
    // at the given byte index, successively up to the given count times, into the buffer.
    // NOTE the units: The buffer is bytes; the index is in bytes; the count refers to the
    // number of 4-byte (UInt32 - NOT byte) values; and value is a 4-byte (UInt32) value.
    //
    //   buffer.withUnsafeMutableBytes { raw in
    //       let base: UnsafeMutableRawPointer = raw.baseAddress!.advanced(by: your_index)
    //       Memory.fastcopy(to: base, count: your_count, value: your_value)
    //   }
    //
    @inline(__always)
    public static func fastcopy(to base: UnsafeMutableRawPointer, count: Int, value: UInt32) {
        //
        // ChatGPT had suggested assigning value.bigEndian to rvalue here, but turns out we
        // do not actually need it and without is slightly faster (e.g. 2.27175 vs. 3.01660).
        // However: To make this work had to reverse the way we deal with pixel values,
        // e.g. (UInt32(red) << 0) | (UInt32(green) << 8) | (UInt32(blue) << 16) | (UInt32(alpha) << 24)
        // not: (UInt32(red) << 24) | (UInt32(green) << 16) | (UInt32(blue) << 8) | (UInt32(alpha) << 0)
        //
        var rvalue = value
        memset_pattern4(base, &rvalue, count * Memory.bufferBlockSize)
    }

    // This version of the above with special cases for 1 and 2 (also tried with 3)
    // is actually not any faster; slightly slower in fact (e.g. 3.01660 vs. 3.29970).
    //
    @inline(__always)
    public static func slightly_slower_fastcopy(to base: UnsafeMutableRawPointer, count: Int, value: UInt32) {
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

    // Copies (fast) the given (UInt32) value to the given (UInt8 array) buffer starting
    // at the given byte index, successively up to the given count times, into the buffer.
    // NOTE the units: The buffer is bytes; the index is in bytes; the count refers to the
    // number of 4-byte (UInt32 - NOT byte) values; and value is a 4-byte (UInt32) value.
    //
    //   Memory.fastcopy(to: &buffer, count: your_count, value: your_value)
    //
    public static func fastcopy(to buffer: inout [UInt8], index: Int, count: Int, value: UInt32) {
        let byteIndex: Int = index
        let byteCount: Int = count * Memory.bufferBlockSize
        guard byteIndex >= 0, byteIndex + byteCount <= buffer.count else {
            //
            // Out of bounds.
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

    public static func allocate(_ size: Int, initialize: UInt8? = nil) -> [UInt8] {
        if ((initialize != nil) && (initialize! > 0)) {
            return [UInt8](repeating: initialize!, count: size)
        }
        else {
            return [UInt8](unsafeUninitializedCapacity: size) {  buffer, initializedCount in
                initializedCount = size
            }
        }
    }
}
