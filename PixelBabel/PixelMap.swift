import Foundation
import SwiftUI

let ScreenWidth = Int(UIScreen.main.bounds.width)
let ScreenHeight = Int(UIScreen.main.bounds.height)
let ScreenDepth = 4

class PixelMap {

    private var _pixels: [UInt8]
    private var _pixelsWidth: Int
    private var _pixelsHeight: Int
    private var _scale: Int = 1
    private var _mode: ColorMode = ColorMode.color

    private var _producer: Bool
    private var _backgroundBufferSize: Int = DefaultAppSettings.backgroundBufferSizeDefault
    private var _pixelsList: [[UInt8]]? = nil
    private var _pixelsListAccessQueue: DispatchQueue? = nil
    private var _pixelsListReplenishQueue: DispatchQueue? = nil

    init(_ width: Int, _ height: Int,
         scale: Int = 1,
         mode: ColorMode = ColorMode.color,
         backgroundBufferSize: Int = DefaultAppSettings.backgroundBufferSizeDefault) {
        self._producer = true
        self._pixelsWidth = width
        self._pixelsHeight = height
        self._scale = scale
        self._pixels = [UInt8](repeating: 0, count: self._pixelsWidth * self._pixelsHeight * ScreenDepth)
        self._producer = backgroundBufferSize > 0
        if (self._producer) {
            self._backgroundBufferSize = backgroundBufferSize
            self._pixelsList = []
            self._pixelsListAccessQueue = DispatchQueue(label: "PixelBabel.PixelMap.ACCESS")
            self._pixelsListReplenishQueue = DispatchQueue(label: "PixelBabel.PixelMap.REPLENISH")
            self._replenish()
        }
    }

    public var width: Int {
        return (self._pixelsWidth + self._scale - 1) / self._scale
    }

    public var height: Int {
        return (self._pixelsHeight + self._scale - 1) / self._scale
    }

    public var scale: Int {
        get { return self._scale }
        set { self._scale = newValue ; self._invalidate() }
    }

    public var mode: ColorMode {
        get { return self._mode }
        set { self._mode = newValue ; self._invalidate() }
    }

    public var data: [UInt8] {
        get { return self._pixels }
        set { self._pixels = newValue }
    }

    public var producer: Bool {
        get { return self._producer }
        set {
            self._producer = newValue
            if (!self._producer) {
                self._invalidate()
            }
        }
    }

    public var backgroundBufferSize: Int {
        get { return self._backgroundBufferSize }
        set { self._backgroundBufferSize = newValue }
    }

    public var cached: Int {
        get {
            var pixelsListCount: Int = 0
            if (self._pixelsListAccessQueue != nil) {
                self._pixelsListAccessQueue!.sync {
                    pixelsListCount = self._pixelsList!.count
                }
            }
            return pixelsListCount
        }
    }

    public func randomize()
    {
        var done: Bool = false
        if (self._producer) {
            var pixels: [UInt8]? = nil
            self._pixelsListAccessQueue!.sync {
                // This block of code effectively synchronizes
                // access to pixelsList between producer and consumer.
                if !self._pixelsList!.isEmpty {
                    pixels = self._pixelsList!.removeFirst()
                }
            }
            if (pixels != nil) {
                self._pixels = pixels!
                done = true
            }
            self._replenish()
        }
        if (!done) {
            PixelMap._randomize(&self._pixels, self._pixelsWidth, self._pixelsHeight,
                                width: self.width, height: self.height, scale: self.scale, mode: self.mode)
        }
    }

    public func load(_ name: String, pixelate: Bool = true)
    {
        guard let image = UIImage(named: name),
            let cgImage: CGImage = image.cgImage else {
            return
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
        guard let context = CGContext(
            data: &self._pixels,
            width: self._pixelsWidth,
            height: self._pixelsHeight,
            bitsPerComponent: 8,
            bytesPerRow: self._pixelsWidth * ScreenDepth,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return
        }

        var finalImage: CGImage = cgImage

        context.draw(finalImage, in: CGRect(x: 0, y: 0, width: self._pixelsWidth, height: self._pixelsHeight))

        if (pixelate) {
            if let image = ImageUtils.pixelate(finalImage, self._pixelsWidth, self._pixelsHeight, pixelSize: self._scale) {
                guard let context = CGContext(
                    data: &self._pixels,
                    width: self._pixelsWidth,
                    height: self._pixelsHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: self._pixelsWidth * ScreenDepth,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo.rawValue
                ) else {
                    return
                }
                context.draw(image, in: CGRect(x: 0, y: 0, width: self._pixelsWidth, height: self._pixelsHeight))
                finalImage = image
            }
        }

        if (self.mode == ColorMode.monochrome) {
            if let image = ImageUtils.monochrome(finalImage) {
                guard let context = CGContext(
                    data: &self._pixels,
                    width: self._pixelsWidth,
                    height: self._pixelsHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: self._pixelsWidth * ScreenDepth,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo.rawValue
                ) else {
                    return
                }
                context.draw(image, in: CGRect(x: 0, y: 0, width: self._pixelsWidth, height: self._pixelsHeight))
                finalImage = image
            }
        }

        if (self.mode == ColorMode.grayscale) {
            if let image = ImageUtils.grayscale(finalImage) {
                guard let context = CGContext(
                    data: &self._pixels,
                    width: self._pixelsWidth,
                    height: self._pixelsHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: self._pixelsWidth * ScreenDepth,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo.rawValue
                ) else {
                    return
                }
                context.draw(image, in: CGRect(x: 0, y: 0, width: self._pixelsWidth, height: self._pixelsHeight))
                finalImage = image
            }
        }
    }

    static func _randomize(_ pixels: inout [UInt8], _ pixelsWidth: Int, _ pixelsHeight: Int,
                           width: Int, height: Int, scale: Int, mode: ColorMode)
    {
        for y in 0..<height {
            for x in 0..<width {
                if (mode == ColorMode.monochrome) {
                    let value: UInt8 = UInt8.random(in: 0...1) * 255
                    PixelMap._write(&pixels, pixelsWidth, pixelsHeight,
                                    x: x, y: y, scale: scale, red: value, green: value, blue: value)
                }
                else if (mode == ColorMode.grayscale) {
                    let value = UInt8.random(in: 0...255)
                    PixelMap._write(&pixels, pixelsWidth, pixelsHeight,
                                    x: x, y: y, scale: scale, red: value, green: value, blue: value)
                }
                else {
                    let rgb = UInt32.random(in: 0...0xFFFFFF)
                    let red = UInt8((rgb >> 16) & 0xFF)
                    let green = UInt8((rgb >> 8) & 0xFF)
                    let blue = UInt8(rgb & 0xFF)
                    PixelMap._write(&pixels, pixelsWidth, pixelsHeight,
                                     x: x, y: y, scale: scale, red: red, green: green, blue: blue)
                }
            }
        }
    }

    static func _write(_ pixels: inout [UInt8], _ pixelsWidth: Int, _ pixelsHeight: Int,
                       x: Int, y: Int, scale: Int,
                       red: UInt8, green: UInt8, blue: UInt8, transparency: UInt8 = 255)
    {
        for dy in 0..<scale {
            for dx in 0..<scale {
                let ix = x * scale + dx
                let iy = y * scale + dy
                let i = (iy * pixelsWidth + ix) * ScreenDepth
                if ((ix < pixelsWidth) && (i < pixels.count)) {
                    pixels[i] = red
                    pixels[i + 1] = green
                    pixels[i + 2] = blue
                    pixels[i + 3] = transparency
                }
            }
        }
    }

    private func _replenish() {
        self._pixelsListReplenishQueue!.async {
            // This block of code runs OFF of the main thread (i.e. in the background);
            // and no more than one of these will ever be running at a time. 
            var additionalPixelsProbableCount: Int = 0
            self._pixelsListAccessQueue!.sync {
                // This block of code is effectively to synchronize
                // access to pixelsList between (this) producer and consumer.
                additionalPixelsProbableCount = self._backgroundBufferSize - self._pixelsList!.count
            }
            if (additionalPixelsProbableCount > 0) {
                for i in 0..<additionalPixelsProbableCount {
                    var pixels: [UInt8] = [UInt8](repeating: 0, count: self._pixelsWidth * self._pixelsHeight * ScreenDepth)
                    PixelMap._randomize(&pixels, self._pixelsWidth, self._pixelsHeight,
                                        width: self.width, height: self.height, scale: self.scale, mode: self.mode)
                    self._pixelsListAccessQueue!.sync {
                        if (self._pixelsList!.count < self._backgroundBufferSize) {
                            self._pixelsList!.append(pixels)
                        }
                    }
                }
            }
        }
    }

    public func _invalidate()
    {
        if (self._pixelsListAccessQueue != nil) {
            self._pixelsListAccessQueue!.sync {
                self._pixelsList!.removeAll()
            }
        }
    }
}
