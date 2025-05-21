import Foundation

// Implements a true arithmetic modulo operation.
//
// Turns out most programming languages (e.g. Swift, Java, C/C++ , JavaScript, Rust, Go) implement
// the "mod" operator (i.e. %) as a simple remainder operator, but some languages (e.g. Python, Ruby)
// implement it as a true arithmetic modulo operator, which can give different results when negative
// numbers are involved; so for example in Swift the expression -1 % 5 gives -1 but in Python it gives 4. 
//
// This came up with my CellGridView code (2025-05-21) with this property definition:
//
//   var shiftXR: Int { (cellSize + shiftX - viewWidthExtra) % cellSize }
//
// which for cellSize == 146, shiftX == -76, viewWidthExtra == 139 gives -69 but
// we really want it to give 77; so we change it to this to get the desired result:
//
//   var shiftXR: Int { modulo(cellSize + shiftX - viewWidthExtra, cellSize) }
//
@inlinable
public func modulo(_ value: Int, _ modulus: Int) -> Int {
    let remainder: Int = value % modulus
    return remainder >= 0 ? remainder : remainder + modulus
}
