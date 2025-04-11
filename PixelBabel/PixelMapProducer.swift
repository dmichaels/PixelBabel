import Foundation
import SwiftUI

class PixelMapProducer {

    private var _displayWidth: Int
    private var _displayHeight: Int
    private var _pixelMapWidth: Int
    private var _pixelMapHeight: Int
    private var _pixelMapScale: Int
    private var _pixelMapMode: ColorMode
    private var _pixelMapShape: PixelShape
    private var _pixelMapFilter: RGBFilterOptions
    private var _pixelMapBackground: Pixel
    private var _pixelMapMargin: Int
    private var _bufferSize: Int
    private var _buffer: [[UInt8]]
    private var _bufferAccessQueue: DispatchQueue
    private var _bufferReplenishQueue: DispatchQueue

    init(_ pixelMap: PixelMap, bufferSize: Int = DefaultAppSettings.backgroundBufferSizeDefault) {
        self._displayWidth = pixelMap._pixelsWidth
        self._displayHeight = pixelMap._pixelsHeight
        self._pixelMapWidth = pixelMap.width
        self._pixelMapHeight = pixelMap.height
        self._pixelMapMode = pixelMap.mode
        self._pixelMapShape = pixelMap.shape
        self._pixelMapScale = pixelMap.scale
        self._pixelMapFilter = pixelMap.filter
        self._pixelMapMargin = 0 // TODO
        self._pixelMapBackground = pixelMap.background
        self._bufferSize = backgroundBufferSize
        self._buffer = []
        self._bufferAccessQueue = DispatchQueue(label: "PixelBabel.PixelMapProducer.ACCESS")
        self._bufferReplenishQueue = DispatchQueue(label: "PixelBabel.PixelMapProducer.REPLENISH")
        self.replenish()
    }

    public var cached: Int {
        get {
            var bufferCount: Int = 0
            self._bufferAccessQueue.sync {
                bufferCount = self._buffer!.count
            }
            return bufferCount
        }
    }

    public func replenish() {
        self._bufferReplenishQueue.async {
            // This block of code runs OFF of the main thread (i.e. in the background);
            // and no more than one of these will ever be running at a time. 
            var additionalPixelsProbableCount: Int = 0
            self._bufferAccessQueue.sync {
                // This block of code is effectively to synchronize
                // access to pixelsList between (this) producer and consumer (PixelMap).
                additionalPixelsProbableCount = self._bufferSize - self._buffer.count
            }
            if (additionalPixelsProbableCount > 0) {
                for i in 0..<additionalPixelsProbableCount {
                    var pixels: [UInt8] = [UInt8](repeating: 0,
                                                  count: self._displayWidth * self._displayHeight * ScreenDepth)
                    PixelMap._randomize(
                        &pixels, self._displayWidth, self._displayHeight,
                        width: self._pixelMapWidth, height: self._pixelMapHeight,
                        scale: self._pixelMapScale, mode: self._pixelMapMode, filter: self._pixelMapFilter)
                    self._bufferAccessQueue.sync {
                        if (self._buffer.count < self._bufferSize) {
                            self._buffer.append(pixels)
                        }
                    }
                }
            }
        }
    }

    public func clear()
    {
        self._bufferAccessQueue.sync {
            self._buffer.removeAll()
        }
    }
}
