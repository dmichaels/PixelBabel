import SwiftUI

public final class Screen: @unchecked Sendable
{
    // TODO
    // NO NEVERMIND THIS STILL WONT WORK IN EXTERNAL PACKAGE/LIBRARY ...
    // Going to just have to not support a singleton for Screen, as it needs to be initialized
    // with something that is not available until runtime, and which we cannot even use directly
    // here without interferring with our ability to put this into a shared external reusable package.
    // So think we will just create one of these in ContentView and pass to CellGridView for keeping/usage.
    //
    // N.B. If you want to use the above (shared) singleton then an instance of this class MUST be created first
    // thing in from your app, i.e. let screen = Screen(size: UIScreen.main.bounds, scale: UIScreen.main.scale).
    // It is setup this way because UIScreen may not be used within this class if we want this to be available
    // from an external library/package, to due @MainActor complications.

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
    public func scale(scaling: Bool = true) -> CGFloat { return scaling ? self._scale : 1.0 }
    //
    // The channels is simply the number of bytes (UInt8) in a pixel,
    // i.e. one byte for each of: red, blue, green, alpha (aka RGBA)
    //
    public let channels: Int = 4
    //
    // And for flexibility make this channels available as an instance
    // or class/static property; this surprisingly is allowed in Swift.
    //
    public static let channels: Int = 4

    public func scaled(_ value: Int, scaling: Bool = true) -> Int {
        return scaling ? Int(round(CGFloat(value) * self._scale)) : value
    }

    public func scaled(_ value: CGFloat, scaling: Bool = true) -> CGFloat {
        return scaling ? value * self._scale : value
    }

    public func unscaled(_ value: Int, scaling: Bool = true) -> Int {
        return scaling ? Int(round(CGFloat(value) / self._scale)) : value
    }

    public func unscaled(_ value: CGFloat, scaling: Bool = true) -> CGFloat {
        return scaling ? value / self._scale : value
    }
}
