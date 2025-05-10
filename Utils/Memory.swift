import Foundation

public struct Memory
{
    public static let bufferBlockSize: Int = 4

    // Copies (fast) the given (UInt32) value to the given (UInt8 array) buffer starting
    // at the given byte index, successively up to the given count times, into the buffer.
    // Note the units: The buffer is bytes; the index is in bytes; the count refers to the
    // number of 4-byte (UInt32 - NOT byte) values; and value is a 4-byte (UInt32) value.
    //
    public static func fastcopy(to buffer: inout [UInt8], index: Int, count: Int, value: UInt32) {
        let byteIndex = index
        let byteCount = count * Memory.bufferBlockSize
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

    // Same as above except the caller passes in the unsafe mutable byte-array buffer,
    // and thus the index will not need to be passed; usage would be like this:
    //
    //     buffer.withUnsafeMutableBytes { raw in
    //         let base: UnsafeMutableRawPointer = raw.baseAddress!.advanced(by: your_index)
    //         Memory.fastcopy(to: base, count: your_count, value: your_value)
    //     }
    //
    public static func fastcopy(to base: UnsafeMutableRawPointer, count: Int, value: UInt32) {
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
