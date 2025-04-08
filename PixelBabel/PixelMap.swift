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

    private let _producer: Bool
    private let _pixelsListMax: Int = 21
    private var _pixelsList: [[UInt8]]? = nil
    private var _pixelsListAccessQueue: DispatchQueue? = nil
    private var _pixelsListReplenishQueue: DispatchQueue? = nil

    init(_ width: Int, _ height: Int, scale: Int = 1, mode: ColorMode = ColorMode.color, producer: Bool = true) {
        print("PixelMap.init: \(producer)")
        self._pixelsWidth = width
        self._pixelsHeight = height
        self._scale = scale
        self._pixels = [UInt8](repeating: 0, count: self._pixelsWidth * self._pixelsHeight * ScreenDepth)
        print("CREATE-PIXELS: [\(self._pixelsWidth * self._pixelsHeight * ScreenDepth)]")
        // xyzzy
        self._pixels.withUnsafeBufferPointer { buffer in
            let address = buffer.baseAddress
            let raw = UInt(bitPattern: address)
            let hex = String(raw, radix: 16, uppercase: true)
            print("CREATE-PIXELS-INIT-ADDRESS: [\(hex)]")
        }
        // xyzzy
        self._producer = producer
        if (producer) {
            self._pixelsList = []
            self._pixelsListAccessQueue = DispatchQueue(label: "PixelBabel.PixelMap.ACCESS" /*, qos: .background */)
            self._pixelsListReplenishQueue = DispatchQueue(label: "PixelBabel.PixelMap.REPLENISH", qos: .background)
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
        set { self._scale = newValue }
    }

    public var mode: ColorMode {
        get { return self._mode }
        set { self._mode = newValue }
    }

    public var data: [UInt8] {
        get { return self._pixels }
        set { self._pixels = newValue }
    }

    public func randomize()
    {
        var done: Bool = false
        if (self._producer) {
            var pixels: [UInt8]? = nil
            self._pixelsListAccessQueue!.sync {
                print("RANDOMIZE: IN-SYNC-BLOCK: [\(self._pixelsList!.count)]")
                // This block of code effectively synchronizes
                // access to pixelsList between producer and consumer.
                if !self._pixelsList!.isEmpty {
                    pixels = self._pixelsList!.removeFirst()
                    print("RANDOMIZE: IN-SYNC-BLOCK: [\(self._pixelsList!.count)] GOT-PIXELS [\(pixels != nil ? 1 : 0)]")
                    done = true
                }
                else {
                    print("PixelMap.randomize.initial")
                }
            }
            print("RANDOMIZE: AFTER-SYNC-BLOCK: [\(pixels != nil ? 1 : 0)] [\(done)]")
            if (pixels != nil) {
                print("RANDOMIZE: USE-CACHED PIXELS")
                self._pixels = pixels!
            }
            self._replenish()
        }
        if (!done) {
            print("RANDOMIZE: USE-EXISTING PIXELS")
            PixelMap._randomize(&self._pixels, self._pixelsWidth, self._pixelsHeight,
                                width: self.width, height: self.height, scale: self.scale, mode: self.mode)
        }
    }


    public func obsolete_randomize()
    {
        var done: Bool = false
        print("xyzzy.a")
        if (self._producer) {
            print("xyzzy.b")
            self._pixelsListAccessQueue!.async {
                print("FOO: [\(self._pixelsList!.count)]")
                print("xyzzy.c")
                // This block of code effectively synchronizes
                // access to pixelsList between producer and consumer.
                if !self._pixelsList!.isEmpty {
                    print("xyzzy.d")
                    print("PixelMap.randomize.grab-pre-computed-pixels-todo: [\(self._pixelsList!.count)]")
                    var pixels: [UInt8]? = self._pixelsList!.removeFirst()
                    print("PixelMap.randomize.grab-pre-computed-pixels-done: [\(self._pixelsList!.count)]")
                    // xyzzy
                    pixels!.withUnsafeBufferPointer { buffer in
                        let address = buffer.baseAddress
                        let raw = UInt(bitPattern: address)
                        let hex = String(raw, radix: 16, uppercase: true)
                        print("GRAB-PIXELS-ADDRESS: [\(hex)]")
                    }
                    // xyzzy
                    self._pixels = pixels!
                    pixels = nil
                    done = true
                    // pixels = nil
                    // print("PixelMap.randomize.c")
                    // print("PixelMap.randomize.d")
                }
                else {
                    print("xyzzy.e")
                    print("PixelMap.randomize.initial")
                }
                print("xyzzy.f")
            }
            print("xyzzy.g")
            self._replenish()
            print("xyzzy.h")
        }
        print("xyzzy.i")
        if (!done) {
            print("randomize.xyzzy")
            // let pixelMap: PixelMap = PixelMap(self._pixelsWidth, self._pixelsHeight,
            //                                   scale: self._scale, mode: self._mode, producer: false)
            // PixelMap.obsolete_randomize(pixelMap)
            // self._pixels = pixelMap._pixels
            // PixelMap.obsolete_randomize(self)
            // xyzzy
            self._pixels.withUnsafeBufferPointer { buffer in
                let address = buffer.baseAddress
                let raw = UInt(bitPattern: address)
                let hex = String(raw, radix: 16, uppercase: true)
                print("CALL-RANDOMIZE-FROM-NOT-DONE-PIXELS-ADDRESS: [\(hex)]")
            }
            // xyzzy
            PixelMap._randomize(&self._pixels, self._pixelsWidth, self._pixelsHeight,
                                width: self.width, height: self.height, scale: self.scale, mode: self.mode)
        }
    }

    public func load(_ name: String)
    {
        guard let image = UIImage(named: name),
            let cgImage = image.cgImage else {
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

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: self._pixelsWidth, height: self._pixelsHeight))
    }

    public func invalidate()
    {
        if (self._producer) {
            self._pixelsListAccessQueue!.sync {
                self._pixelsList!.removeAll()
            }
        }
    }

    static func _randomize(_ pixels: inout [UInt8], _ pixelsWidth: Int, _ pixelsHeight: Int,
                           width: Int, height: Int, scale: Int, mode: ColorMode)
    {
        // xyzzy
        pixels.withUnsafeBufferPointer { buffer in
            let address = buffer.baseAddress
            let raw = UInt(bitPattern: address)
            let hex = String(raw, radix: 16, uppercase: true)
            print("RANDOMIZE-PIXELS-ADDRESS: [\(hex)]")
        }
        // xyzzy
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
                    //xyzzy
                    // print("XX: [\(i)] [\(pixels.count)]")
                    if i >= 0 && i < pixels.count {
                        pixels[i] = red
                    }
                    else {
                        print("ERROR: index \(index) out of bounds; pixels.count = \(pixels.count)")
                    }
                    //xyzzy
                    // pixels[i] = red
                    pixels[i + 1] = green
                    pixels[i + 2] = blue
                    pixels[i + 3] = transparency
                }
            }
        }
    }

    private func _replenish() {
        // DispatchQueue.global(qos: .background).async {
        self._pixelsListReplenishQueue!.async {
            print("_replenish.start")
            // This block of code runs OFF of the main thread (i.e. in the background);
            // and no more than one of these will ever be running at a time. 
            var additionalPixelsProbableCount: Int = 0
            // self._pixelsListAccessQueue!.async {
                // This block of code is effectively to synchronize
                // access to pixelsList between (this) producer and consumer.
                additionalPixelsProbableCount = self._pixelsListMax - self._pixelsList!.count
                print("_replenish.probable-count: [\(self._pixelsListMax)] - [\(self._pixelsList!.count)] = [\(additionalPixelsProbableCount)]")
            // }
            print("_replenish.probable-count-after-async: [\(additionalPixelsProbableCount)]")
            if (additionalPixelsProbableCount > 0) {
                print("_replenish.probable-count-yes: [\(additionalPixelsProbableCount)]")
                var additionalPixelsProbableList: [[UInt8]] = []
                for i in 0..<additionalPixelsProbableCount {
                    print("_replenish.probable-count-loop: [\(i)] in [\(additionalPixelsProbableCount)]")
                    if (true) {
                        var pixels = [UInt8](repeating: 0, count: self._pixelsWidth * self._pixelsHeight * ScreenDepth)
                        print("CREATE-PIXELS-PRODUCER: [\(self._pixelsWidth * self._pixelsHeight * ScreenDepth)]")
                        // xyzzy
                        pixels.withUnsafeBufferPointer { buffer in
                            let address = buffer.baseAddress
                            let raw = UInt(bitPattern: address)
                            let hex = String(raw, radix: 16, uppercase: true)
                            print("CREATE-PIXELS-PRODUCER-ADDRESS: [\(hex)]")
                        }
                        // xyzzy
                        PixelMap._randomize(&pixels, self._pixelsWidth, self._pixelsHeight,
                                            width: self.width, height: self.height, scale: self.scale, mode: self.mode)
                        additionalPixelsProbableList.append(pixels)
                    }
                    else {
                        let pixelMap: PixelMap = PixelMap(self._pixelsWidth, self._pixelsHeight,
                                                          scale: self._scale, mode: self._mode, producer: false)
                        pixelMap.randomize()
                        additionalPixelsProbableList.append(pixelMap._pixels)

                    }
                }
                self._pixelsListAccessQueue!.sync {
                    let additionalPixelsActualCount: Int = self._pixelsListMax - self._pixelsList!.count
                    print("_replenish.actual-count: [\(self._pixelsListMax)] - [\(self._pixelsList!.count)] = [\(additionalPixelsActualCount)]")
                    if (additionalPixelsActualCount > 0) {
                        // This block of code is effectively to synchronize
                        // access to pixelsList between (this) producer and consumer.
                        print("replenishPixelsListAsync.additional-actual-count: [\(additionalPixelsActualCount)] to [\(self._pixelsList!.count)]")
                        self._pixelsList!.append(contentsOf: additionalPixelsProbableList.prefix(additionalPixelsActualCount))
                        print("replenishPixelsListAsync.additional-append-done: [\(additionalPixelsActualCount)] to [\(self._pixelsList!.count)]")
                    }
                }
            }
            print("_replenish.end")
        }
    }
}

