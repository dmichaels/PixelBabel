import SwiftUI

@MainActor
public class Screen: ObservableObject
{
    public static let shared: Screen = Screen()

    // These initial values are technically just guesses as the real info should be
    // be obtained via the onAppear event of the main view within a GeometryReader;
    // from which should be Screen.configure.
    //
    public static let initialWidth: Int = Int(UIScreen.main.bounds.width)
    public static let initialHeight: Int = Int(UIScreen.main.bounds.height)
    public static let initialScale: CGFloat = UIScreen.main.scale
    //
    // This depth (aka channels) is the number of byte (UInt8) elements in
    // a pixel i.e. one byte each for red, blue, green, and alpha, aka RGBA.
    //
    public static let depth: Int = 4

    private var _initialized: Bool = false
    private var _width: Int = initialWidth
    private var _height: Int = initialHeight
    private var _scale: CGFloat = initialScale

    public var width: Int {
        self._width
    }

    public var height: Int {
        self._height
    }

    public var size: CGSize {
        CGSize(width: CGFloat(self.width), height: CGFloat(self.height))
    }

    public var initialized: Bool {
        self._initialized
    }

    // Returns the scaling factor for the screen. This is the nunmber physical pixels
    // per logical pixel (points); i.e. for Retina displays; e.g. the iPhone 15 Pro has
    // a scaling factor of 3.0 meaning 3 pixels per logical pixel per dimension, i.e per
    // horizontal/vertical, i.e. meaning 9 (3 * 3) physical pixels per one logical pixels.
    //
    public func scale(scaling: Bool = true) -> CGFloat {
        return scaling ? self._scale : 1.0
    }

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

    public func initialize(size: CGSize, scale: CGFloat) {
        //
        // N.B. This should be called from within
        // the onAppear within the main ContentView.
        //
        self._width = Int(size.width)
        self._height = Int(size.height)
        self._scale = scale
        self._initialized = true
    }
}
