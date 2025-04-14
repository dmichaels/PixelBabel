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

    public var scaledWidth: Int {
        Int(round(CGFloat(self._width) * self._scale))
    }

    public var scaledHeight: Int {
        Int(round(CGFloat(self._height) * self._scale))
    }

    public var size: CGSize {
        CGSize(width: CGFloat(self.width), height: CGFloat(self.height))
    }

    public var scaledSize: CGSize {
        CGSize(width: CGFloat(self.scaledWidth), height: CGFloat(self.scaledHeight))
    }

    public var scale: CGFloat {
        self._scale 
    }

    public var bufferSize: Int {
        self.scaledWidth * self.scaledHeight * self.channels
    }

    public let channels: Int = 4

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
