import SwiftUI

@MainActor
public class ScreenInfo: ObservableObject
{
    public static let shared = ScreenInfo()

    // These initial values are technically just guesses as the real info should be
    // be obtained via the onAppear event of the main view within a GeometryReader;
    // from which should be ScreenInfo.configure.
    //
    public static let initialWidth: Int = Int(UIScreen.main.bounds.width)
    public static let initialHeight: Int = Int(UIScreen.main.bounds.height)
    public static let initialScale: CGFloat = UIScreen.main.scale
    //
    // This depth (aka channels) is the number of byte (UInt8) elements in
    // a pixel i.e. one byte each for red, blue, green, and alpha, aka RGBA.
    //
    public static let depth: Int = 4

    var _width: Int = initialWidth
    var _height: Int = initialHeight
    var _scale: CGFloat = initialScale

    public var width: Int {
        self._width
    }

    public var height: Int {
        self._height
    }

    public var size: CGSize {
        CGSize(width: CGFloat(self.width), height: CGFloat(self.height))
    }

    // Returns the scaling factor for the screen/display.
    // This is the nunmber physical pixels per logical pixel (points).
    // This is to Retina displays; e.g. the iPhone 15 has a scaling 
    // factor of 3.0 meaning 3 pixels per logical pixel.
    //
    public var scale: CGFloat {
        self._scale 
    }

    public func configure(size: CGSize, scale: CGFloat) {
        //
        // N.B. This should be called from within
        // the onAppear within the main ContentView.
        //
        self._width = Int(size.width)
        self._height = Int(size.height)
        self._scale = scale
    }
}
