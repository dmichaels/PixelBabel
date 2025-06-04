import SwiftUI

public final class Screen: @unchecked Sendable
{
    // N.B. We offer no (shared) singleton for this class as we initially want to; there are complications
    // with this because it uses UIScreen which is a @MainActor which would require this class to be so as
    // well, which can be problematic if we want to put this within an external/reusable package; and also
    // there are complications because technically the screen size should not actually be obtained from
    // UIScreen.main.bounds but rather from the geometry.size value in a GeometryReader.onAppear call.

    private let _width: Int
    private let _height: Int
    private let _scale: CGFloat

    public init(size: CGSize, scale: CGFloat) {
        self._width = Int(size.width)
        self._height = Int(size.height)
        self._scale = scale
    }

    public var width: Int { self._width }
    public var height: Int { self._height }
    public var size: CGSize { CGSize(width: CGFloat(self.width), height: CGFloat(self.height)) }
    public var scale: CGFloat { self._scale }
    //
    // The scale is the scaling factor for the screen, which is the nunmber physical pixels
    // per logical pixel (points); i.e. for Retina displays; e.g. the iPhone 15 Pro has
    // a scaling factor of 3.0 meaning 3 pixels per logical pixel per dimension, i.e per
    // horizontal/vertical, i.e. meaning 9 (3 * 3) physical pixels per one logical pixels.
    //
    public func scale(scaling: Bool = true) -> CGFloat { scaling ? self._scale : 1.0 }
    //
    // The channels is simply the number of bytes (UInt8) in a pixel,
    // i.e. one byte for each of: red, blue, green, alpha (aka RGBA)
    //
    public let channels: Int = Screen.channels
    //
    // And for flexibility make this channels available as an instance
    // or class/static property; this surprisingly is allowed in Swift.
    //
    public static let channels: Int = 4

    // These functions scale the given value as appropriate; there are versions which
    // take integer or floating point; as well as ones which take a scaling boolean
    // indicating whether or not to really scale the value.
    //
    public func scaled(_ value: Int) -> Int { Int(round(CGFloat(value) * self._scale)) }
    public func scaled(_ value: CGFloat) -> CGFloat { value * self._scale }
    public func scaled(_ value: Int, scaling: Bool) -> Int {
        scaling ? Int(round(CGFloat(value) * self._scale)) : value
    }
    public func scaled(_ value: CGFloat, scaling: Bool) -> CGFloat {
        scaling ? value * self._scale : value
    }

    public func unscaled(_ value: Int) -> Int { Int(round(CGFloat(value) / self._scale)) }
    public func unscaled(_ value: CGFloat) -> CGFloat { value / self._scale }
    public func unscaled(_ value: Int, scaling: Bool) -> Int {
        scaling ? Int(round(CGFloat(value) / self._scale)) : value
    }
    public func unscaled(_ value: CGFloat, scaling: Bool) -> CGFloat {
        scaling ? value / self._scale : value
    }
}
