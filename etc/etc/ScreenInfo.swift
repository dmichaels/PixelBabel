import SwiftUI

@MainActor
class ScreenInfo: ObservableObject
{
    static let shared = ScreenInfo()

    @Published private var _width: Int = Int(UIScreen.main.bounds.width)
    @Published private var _height: Int = Int(UIScreen.main.bounds.height)
    @Published private var _scale: CGFloat = UIScreen.main.scale

    public var width: Int {
        self._width
    }

    public var height: Int {
        self._height
    }

    public var size: CGSize {
        CGSize(width: CGFloat(self.width), height: CGFloat(self.height))
    }

    public var scaledWidth: Int {
        Int(round(CGFloat(self._width) * self._scale))
    }

    public var scaledHeight: Int {
        Int(round(CGFloat(self._height) * self._scale))
    }

    public var scaledSize: CGSize {
        CGSize(width: CGFloat(self.scaledWidth), height: CGFloat(self.scaledHeight))
    }
    public let channelSize: Int = 4

    // Returns the scaling factor for the screen/display.
    // This is the nunmber physical pixels per logical pixel (points).
    // This is to Retina displays; e.g. the iPhone 15 has a scaling 
    // factor of 3.0 meaning 3 pixels per logical pixel.
    //
    public var scale: CGFloat {
        self._scale 
    }

    // This is the number of byte (UInt8) elements in a pixel, 
    // i.e. one byte each for red, blue, green, and alpha, aka RGBA.
    //
    static let depth: Int = 4

    // Returns the byte (UInt8) size an in-memory buffer should
    // be to contain all of the pixel (point) data for the screen/display.
    //
    public var bufferSize: Int {
        self.width * self.height * self.channelSize
    }

    // Returns the byte (UInt8) size an in-memory buffer should
    // be to contain all of the pixel (scaled) data for the scree/displayn.
    //
    public var scaledBufferSize: Int {
        self.scaledWidth * self.scaledHeight * self.channelSize
    }

    public static func scaledValue(_ value: Int, scale: CGFloat) -> Int{
        Int(round(CGFloat(value) * scale))
    }

    func configure(size: CGSize, scale: CGFloat) {
        //
        // N.B. This should be called from within
        // the onAppear within the main ContentView.
        //
        self._width = Int(size.width)
        self._height = Int(size.height)
        self._scale = scale
    }
}
