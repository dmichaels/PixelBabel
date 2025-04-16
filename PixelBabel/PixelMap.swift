import Foundation
import SwiftUI

let ScreenWidth = Int(UIScreen.main.bounds.width)
let ScreenHeight = Int(UIScreen.main.bounds.height)
let ScreenDepth = 4

class PixelMap {

    struct MaskKey: Hashable {
        let size: Int
        let shape: PixelShape
        let margin: Int
    }

    private static var _masks: [MaskKey: [Float]] = [:]

    public var _pixels: [UInt8] // xyzzy
    private var _pixelsWidth: Int
    private var _pixelsHeight: Int
    private var _scale: Int = 1
    private var _mode: ColorMode = ColorMode.color
    private var _background: Pixel = Pixel.dark
    private var _shape: PixelShape = PixelShape.square
    private var _margin: Int = 2
    private var _filter: RGBFilterOptions = RGBFilterOptions.RGB
    private var _writeAlgorithm: WriteAlgorithm = DefaultSettings.writeAlgorithm

    private var _producer: Bool
    private var _backgroundBufferSize: Int = DefaultSettings.backgroundBufferSizeDefault
    private var _pixelsList: [[UInt8]]? = nil
    private var _pixelsListAccessQueue: DispatchQueue? = nil
    private var _pixelsListReplenishQueue: DispatchQueue? = nil

    init(_ width: Int, _ height: Int,
         scale: Int = 1,
         mode: ColorMode = ColorMode.color,
         filter: RGBFilterOptions = RGBFilterOptions.RGB,
         shape: PixelShape = PixelShape.square,
         margin: Int = 2,
         backgroundBufferSize: Int = DefaultSettings.backgroundBufferSizeDefault,
         writeAlgorithm: WriteAlgorithm = DefaultSettings.writeAlgorithm) {
        PixelMap._precomputeMasks()
        self._pixelsWidth = width
        self._pixelsHeight = height
        self._pixels = [UInt8](repeating: 0, count: self._pixelsWidth * self._pixelsHeight * ScreenDepth)
        self._mode = mode
        self._scale = scale
        self._shape = shape
        self._margin = margin
        self._filter = filter
        self._producer = backgroundBufferSize > 0
        self._writeAlgorithm = writeAlgorithm
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

    public var shape: PixelShape {
        get { return self._shape }
        set { self._shape = newValue ; self._invalidate() }
    }

    public var margin: Int {
        get { return self._margin }
        set { if (newValue >= 0) { self._margin = newValue ; self._invalidate() } }
    }

    public var background: Pixel {
        get { return self._background }
        set { self._background = newValue ; self._invalidate() }
    }

    public var filter: RGBFilterOptions {
        get { return self._filter }
        set { self._filter = newValue ; self._invalidate() }
    }

    public var data: [UInt8] {
        get { return self._pixels }
        set { self._pixels = newValue }
    }

    public var screenSize: CGSize {
        get { return CGSize(width: self._pixelsWidth, height: self._pixelsHeight) }
        set {
            self._pixelsWidth = Int(newValue.width)
            self._pixelsHeight = Int(newValue.height)
            self._pixels = [UInt8](repeating: 0, count: self._pixelsWidth * self._pixelsHeight * ScreenDepth)
            self._invalidate()
        }
    }

    public var screenWidth: Int {
        get { return self._pixelsWidth }
    }

    public var screenHeight: Int {
        get { return self._pixelsHeight }
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

    public var algorithm: WriteAlgorithm {
        get { return self._writeAlgorithm }
        set { self._writeAlgorithm = newValue }
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
                                width: self.width, height: self.height,
                                scale: self.scale, mode: self.mode,
                                shape: self.shape, margin: self.margin,
                                background: self.background,
                                filter: self.filter,
                                algorithm: self.algorithm)
        }
    }

    public func load(_ name: String, pixelate: Bool = true)
    {
        guard let image = UIImage(named: name),
            let cgImage: CGImage = image.cgImage else {
            return
        }

        self.load(cgImage, pixelate: pixelate)
    }

    public func load(_ image: CGImage, pixelate: Bool = true) {
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

        var finalImage: CGImage = image

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
                           width: Int, height: Int,
                           scale: Int,
                           mode: ColorMode,
                           shape: PixelShape,
                           margin: Int,
                           background: Pixel = Pixel.dark,
                           filter: RGBFilterOptions = RGBFilterOptions.RGB,
                           algorithm: WriteAlgorithm = WriteAlgorithm.auto)
    {
        let start = Date()

        for y in 0..<height {
            for x in 0..<width {
                if (mode == ColorMode.monochrome) {
                    let value: UInt8 = UInt8.random(in: 0...1) * 255
                    PixelMap._write(&pixels, pixelsWidth, pixelsHeight,
                                    x: x, y: y, scale: scale,
                                    red: value, green: value, blue: value,
                                    shape: shape, background: background, margin: margin, algorithm: algorithm)
                }
                else if (mode == ColorMode.grayscale) {
                    let value = UInt8.random(in: 0...255)
                    PixelMap._write(&pixels, pixelsWidth, pixelsHeight,
                                    x: x, y: y, scale: scale,
                                    red: value, green: value, blue: value,
                                    shape: shape, background: background, margin: margin, algorithm: algorithm)
                }
                else {
                    var rgb = UInt32.random(in: 0...0xFFFFFF)
                    if (filter != RGBFilterOptions.RGB) {
                        rgb = filter.function(rgb)
                    }
                    let red = UInt8((rgb >> 16) & 0xFF)
                    let green = UInt8((rgb >> 8) & 0xFF)
                    let blue = UInt8(rgb & 0xFF)
                    PixelMap._write(&pixels, pixelsWidth, pixelsHeight,
                                    x: x, y: y, scale: scale,
                                    red: red, green: green, blue: blue,
                                    shape: shape, background: background, margin: margin, algorithm: algorithm)
                }
            }
        }

        let end = Date()
        let elapsed = end.timeIntervalSince(start)
        print(String(format: "RANDOMIZE-TIME: %.5f seconds", elapsed))
    }

    func write(x: Int, y: Int, red: UInt8, green: UInt8, blue: UInt8, transparency: UInt8 = 255,
               filter: Pixel.FilterFunction? = nil, algorithm: WriteAlgorithm = WriteAlgorithm.auto) {
        PixelMap._write(&self._pixels, self._pixelsWidth, self._pixelsHeight,
                        x: x, y: y, scale: self.scale,
                        red: red, green: green, blue: blue, transparency: transparency,
                        shape: self.shape, background: self.background,
                        margin: self.margin, filter: filter, algorithm: algorithm)
    }

    static func _write(_ pixels: inout [UInt8],
                _ pixelsWidth: Int,
                _ pixelsHeight: Int,
                x: Int,
                y: Int,
                scale: Int,
                red: UInt8,
                green: UInt8,
                blue: UInt8,
                transparency: UInt8 = 255,
                shape: PixelShape = .square,
                background: Pixel = Pixel.dark,
                margin: Int = 0,
                filter: Pixel.FilterFunction? = nil,
                algorithm: WriteAlgorithm = WriteAlgorithm.auto) {

        switch algorithm {
            case WriteAlgorithm.auto:
                if ((shape == PixelShape.square) || (shape == PixelShape.inset) || ((scale - margin) < 6)) {
                    PixelMap._writeLegacy(
                        &pixels, pixelsWidth, pixelsHeight,
                        x: x, y: y, scale: scale,
                        red: red, green: green, blue: blue,
                        transparency: transparency,
                        shape: shape,
                        background: background,
                        margin: margin,
                        filter: filter)
                        return
                }
                break
            case WriteAlgorithm.new:
                break
            case WriteAlgorithm.best:
                PixelMap._writeGood(
                    &pixels, pixelsWidth, pixelsHeight,
                    x: x, y: y, scale: scale,
                    red: red, green: green, blue: blue,
                    transparency: transparency,
                    shape: shape,
                    background: background,
                    margin: margin,
                    filter: filter)
                return
            case WriteAlgorithm.experimental:
                Renderer._write(
                    &pixels, pixelsWidth, pixelsHeight,
                    x: x, y: y, scale: scale,
                    red: red, green: green, blue: blue,
                    transparency: transparency,
                    shape: shape,
                    background: background,
                    margin: margin,
                    filter: filter)
                return
            case WriteAlgorithm.legacy:
                PixelMap._writeLegacy(
                    &pixels, pixelsWidth, pixelsHeight,
                    x: x, y: y, scale: scale,
                    red: red, green: green, blue: blue,
                    transparency: transparency,
                    shape: shape,
                    background: background,
                    margin: margin,
                    filter: filter)
                return
        }

        let key = MaskKey(size: scale, shape: shape, margin: margin)
        guard let mask = PixelMap._masks[key] else {
            print("Warning: Mask not found in cache. Falling back to computed mask.")
            return
        }
        
        let startX = x * scale
        let startY = y * scale
        
        for j in 0..<scale {
            for i in 0..<scale {
                let ix = startX + i
                let iy = startY + j
                if ix >= pixelsWidth || iy >= pixelsHeight { continue }
                
                // Obtain the precomputed coverage value.
                let coverage = mask[j * scale + i]
                
                // Blend the shape color with the background color.
                let shapeAlpha = Float(transparency)
                let bgAlpha: Float = 255.0
                
                let outRed   = Float(red)   * coverage + Float(background.red)   * (1.0 - coverage)
                let outGreen = Float(green) * coverage + Float(background.green) * (1.0 - coverage)
                let outBlue  = Float(blue)  * coverage + Float(background.blue)  * (1.0 - coverage)
                let outAlpha = shapeAlpha      * coverage + bgAlpha              * (1.0 - coverage)
                
                let idx = (iy * pixelsWidth + ix) * ScreenDepth
                if idx + 3 < pixels.count {
                    pixels[idx]     = UInt8(round(outRed))
                    pixels[idx + 1] = UInt8(round(outGreen))
                    pixels[idx + 2] = UInt8(round(outBlue))
                    pixels[idx + 3] = UInt8(round(outAlpha))
                }
            }
        }
    }

    static func _writeGood(_ pixels: inout [UInt8], _ pixelsWidth: Int, _ pixelsHeight: Int,
                       x: Int, y: Int, scale: Int,
                       red: UInt8, green: UInt8, blue: UInt8, transparency: UInt8 = 255,
                       shape: PixelShape = .square,
                       background: Pixel = Pixel.dark,
                       margin: Int = 0,
                       filter: Pixel.FilterFunction? = nil)
    {
        let marginThickness = (margin > 0 && scale >= FixedSettings.pixelSizeMarginMin && shape != .square) ? margin : 0
        let startX = x * scale
        let startY = y * scale
        let endX = startX + scale
        let endY = startY + scale
        let adjustedScale = scale - 2 * marginThickness
        let antialiasWidth: Float = 1.5

        let centerX = Float(startX + scale / 2)
        let centerY = Float(startY + scale / 2)
        let circleRadius = Float(adjustedScale) / 2
        let radiusSquared = circleRadius * circleRadius

        let cornerRadiusFactor: Float = 0.2
        let cornerRadius: Float = Float(adjustedScale) * cornerRadiusFactor
        let cr2 = cornerRadius * cornerRadius

        let minX = Float(startX + marginThickness)
        let minY = Float(startY + marginThickness)
        let maxX = Float(endX - marginThickness)
        let maxY = Float(endY - marginThickness)

        for dy in 0..<scale {
            for dx in 0..<scale {
                let ix = startX + dx
                let iy = startY + dy
                if ix >= pixelsWidth || iy >= pixelsHeight { continue }

                let fx = Float(ix) + 0.5
                let fy = Float(iy) + 0.5

                var alpha: Float = 0

                switch shape {
                case .square, .inset:
                    let inside = (dx >= marginThickness && dx < scale - marginThickness &&
                                  dy >= marginThickness && dy < scale - marginThickness)
                    alpha = inside ? 1 : 0

                case .circle:
                    let dx = fx - centerX
                    let dy = fy - centerY
                    let dist = sqrt(dx * dx + dy * dy)
                    let edgeDist = circleRadius - dist
                    alpha = min(max(edgeDist / antialiasWidth, 0), 1)

                case .rounded:
                    let innerLeft   = minX + cornerRadius
                    let innerRight  = maxX - cornerRadius
                    let innerTop    = minY + cornerRadius
                    let innerBottom = maxY - cornerRadius

                    if fx >= innerLeft && fx <= innerRight &&
                       fy >= minY && fy <= maxY {
                        alpha = 1
                    } else if fy >= innerTop && fy <= innerBottom &&
                              fx >= minX && fx <= maxX {
                        alpha = 1
                    } else {
                        // Top-left
                        let cx = fx < innerLeft ? innerLeft : fx > innerRight ? innerRight : fx
                        let cy = fy < innerTop ? innerTop : fy > innerBottom ? innerBottom : fy
                        let dx = fx - cx
                        let dy = fy - cy
                        let dist = sqrt(dx * dx + dy * dy)
                        let edgeDist = cornerRadius - dist
                        alpha = min(max(edgeDist / antialiasWidth, 0), 1)
                    }
                }

                let i = (iy * pixelsWidth + ix) * ScreenDepth
                if i + 3 >= pixels.count { continue }

                let bgR = Float(background.red)
                let bgG = Float(background.green)
                let bgB = Float(background.blue)

                if let filter = filter, alpha > 0 {
                    filter(&pixels, i)
                } else {
                    let fgR = Float(red)
                    let fgG = Float(green)
                    let fgB = Float(blue)

                    let blendedR = UInt8((fgR * alpha + bgR * (1 - alpha)).rounded())
                    let blendedG = UInt8((fgG * alpha + bgG * (1 - alpha)).rounded())
                    let blendedB = UInt8((fgB * alpha + bgB * (1 - alpha)).rounded())
                    let finalAlpha = UInt8(Float(transparency) * alpha)

                    pixels[i]     = blendedR
                    pixels[i + 1] = blendedG
                    pixels[i + 2] = blendedB
                    pixels[i + 3] = finalAlpha
                }
            }
        }
    }

    static func _writeLegacy(_ pixels: inout [UInt8], _ pixelsWidth: Int, _ pixelsHeight: Int,
                             x: Int, y: Int, scale: Int,
                             red: UInt8, green: UInt8, blue: UInt8, transparency: UInt8 = 255,
                             shape: PixelShape = .square,
                             background: Pixel = Pixel.dark,
                             margin: Int = 0,
                             filter: Pixel.FilterFunction? = nil)
    {
        var marginThickness: Int = 0
        if ((margin > 0) && (scale >= FixedSettings.pixelSizeMarginMin) && (shape != PixelShape.square)) {
            marginThickness = margin
        }

        let startX = x * scale
        let startY = y * scale
        let endX = startX + scale
        let endY = startY + scale

        // let marginThickness: Int = 2
        // let innerMargin = (margin ?? (shape != .square)) ? marginThickness : 0
        let adjustedScale = scale - 2 * marginThickness

        let centerX = Float(startX + scale / 2)
        let centerY = Float(startY + scale / 2)
        let circleRadius = Float(adjustedScale) / 2.0
        let radiusSquared = circleRadius * circleRadius

        for dy in 0..<scale {
            for dx in 0..<scale {
                let ix = startX + dx
                let iy = startY + dy

                if ix >= pixelsWidth || iy >= pixelsHeight { continue }

                let fx = Float(ix) + 0.5
                let fy = Float(iy) + 0.5

                var shouldWrite = false

                switch shape {
                case .square, .inset:
                    shouldWrite = (dx >= marginThickness && dx < scale - marginThickness &&
                                   dy >= marginThickness && dy < scale - marginThickness)

                case .circle:
                    let dxSq = (fx - centerX) * (fx - centerX)
                    let dySq = (fy - centerY) * (fy - centerY)
                    shouldWrite = dxSq + dySq <= radiusSquared

                case .rounded:
                    let cornerRadius: Float = Float(adjustedScale) * 0.25
                    let cr2 = cornerRadius * cornerRadius

                    let minX = Float(startX + marginThickness)
                    let minY = Float(startY + marginThickness)
                    let maxX = Float(endX - marginThickness)
                    let maxY = Float(endY - marginThickness)

                    if fx >= minX + cornerRadius && fx <= maxX - cornerRadius {
                        shouldWrite = fy >= minY && fy <= maxY
                    } else if fy >= minY + cornerRadius && fy <= maxY - cornerRadius {
                        shouldWrite = fx >= minX && fx <= maxX
                    } else {
                        let cx = fx < minX + cornerRadius ? minX + cornerRadius :
                                 fx > maxX - cornerRadius ? maxX - cornerRadius : fx
                        let cy = fy < minY + cornerRadius ? minY + cornerRadius :
                                 fy > maxY - cornerRadius ? maxY - cornerRadius : fy
                        let dx = fx - cx
                        let dy = fy - cy
                        shouldWrite = dx * dx + dy * dy <= cr2
                    }
                }

                let i = (iy * pixelsWidth + ix) * ScreenDepth
                if i + 3 < pixels.count {
                    if shouldWrite {
                        if (filter != nil) {
                            //
                            // This is different from the filter on _randomize.
                            // In this case if a filter is given then the given RGB values are ignored
                            // and we call the filter with the existing pixel value to get the new value.
                            //
                            filter!(&pixels, i)
                        }
                        else {
                            pixels[i] = red
                            pixels[i + 1] = green
                            pixels[i + 2] = blue
                            pixels[i + 3] = transparency
                        }
                    } else {
                        pixels[i] = background.red
                        pixels[i + 1] = background.green
                        pixels[i + 2] = background.blue
                        pixels[i + 3] = transparency
                    }
                }
            }
        }
    }

    private func _replenish() {
        return // xyzzy
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
                    if (!self._producer) {
                        break
                    }
                    var pixels: [UInt8] = [UInt8](repeating: 0, count: self._pixelsWidth * self._pixelsHeight * ScreenDepth)
                    PixelMap._randomize(&pixels, self._pixelsWidth, self._pixelsHeight,
                                        width: self.width, height: self.height,
                                        scale: self.scale, mode: self.mode, shape: self.shape, margin: self.margin,
                                        background: self.background,
                                        filter: self.filter,
                                        algorithm: self.algorithm)
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

    static func _precomputeMasks() {
        for size in 1...50 {
            // For this example, we precompute for square, circle, and rounded shapes.
            // for shape in [PixelShape.square, PixelShape.circle, PixelShape.rounded] {
            for shape in [PixelShape.circle, PixelShape.rounded] {
                // Allow margin values from 0 up to (roughly) size/4.
                let maxMargin = size / 4
                for margin in 0...maxMargin {
                    let key = MaskKey(size: size, shape: shape, margin: margin)
                    let mask = PixelMap._computeAntialiasMask(size: size, shape: shape, margin: margin)
                    PixelMap._masks[key] = mask
                }
            }
        }
    }

    static func _computeAntialiasMask(size: Int, shape: PixelShape, margin: Int) -> [Float] {
        // Computes an anti‑aliased mask for a given cell size, shape, and margin.
        // - Returns: An array of Floats (values between 0.0 and 1.0) representing the pixel coverage.
        var mask = [Float](repeating: 0.0, count: size * size)
        let scale = size
        var marginThickness = margin
        // Disable margin if scale is too small.
        if margin > 0 && scale < FixedSettings.pixelSizeMarginMin {
            marginThickness = 0
        }
        let adjustedScale = scale - 2 * marginThickness

        // Precalculate values needed for curved shapes.
        let centerX = Float(scale) / 2.0
        let centerY = Float(scale) / 2.0
        let circleRadius = Float(adjustedScale) / 2.0
        let radiusSquared = circleRadius * circleRadius

        // Subpixel sampling using a 2x2 grid.
        let sampleOffsets: [(Float, Float)] = [(-0.25, -0.25),
                                                 (0.25, -0.25),
                                                 (-0.25, 0.25),
                                                 (0.25, 0.25)]
        let sampleCount = Float(sampleOffsets.count)

        // Loop through each pixel in the cell.
        for j in 0..<scale {
            for i in 0..<scale {
                let pixelCenterX = Float(i) + 0.5
                let pixelCenterY = Float(j) + 0.5
                var coverage: Float = 0.0

                if (shape == PixelShape.circle) {
                    // Early-out test:
                    let distX = pixelCenterX - centerX
                    let distY = pixelCenterY - centerY
                    let dist = sqrt(distX * distX + distY * distY)
                    let safetyMargin: Float = 0.3536  // Approximate max distance from center to a sample offset
                    if dist <= circleRadius - safetyMargin {
                        coverage = 1.0
                    } else if dist >= circleRadius + safetyMargin {
                        coverage = 0.0
                    } else {
                        var insideCount: Float = 0.0
                        for offset in sampleOffsets {
                            let sampleX = pixelCenterX + offset.0
                            let sampleY = pixelCenterY + offset.1
                            let dx = sampleX - centerX
                            let dy = sampleY - centerY
                            if (dx * dx + dy * dy) <= radiusSquared {
                                insideCount += 1.0
                            }
                        }
                        coverage = insideCount / sampleCount
                    }
                }
                else if (shape == PixelShape.rounded) {
                    var insideCount: Float = 0.0
                    let cornerRadius: Float = Float(adjustedScale) * 0.25
                    let cr2 = cornerRadius * cornerRadius
                    // Define boundaries for the inner rectangle.
                    let minX = Float(marginThickness)
                    let minY = Float(marginThickness)
                    let maxX = Float(scale - marginThickness)
                    let maxY = Float(scale - marginThickness)
                    for offset in sampleOffsets {
                        let sampleX = pixelCenterX + offset.0
                        let sampleY = pixelCenterY + offset.1
                        var sampleInside = false
                        // Check if sample lies in the non‑curved (straight) areas.
                        if sampleX >= minX + cornerRadius && sampleX <= maxX - cornerRadius {
                            sampleInside = (sampleY >= minY && sampleY <= maxY)
                        } else if sampleY >= minY + cornerRadius && sampleY <= maxY - cornerRadius {
                            sampleInside = (sampleX >= minX && sampleX <= maxX)
                        } else {
                            // Compute distance from the nearest rounded corner.
                            let cx: Float = sampleX < minX + cornerRadius ? minX + cornerRadius :
                                            (sampleX > maxX - cornerRadius ? maxX - cornerRadius : sampleX)
                            let cy: Float = sampleY < minY + cornerRadius ? minY + cornerRadius :
                                            (sampleY > maxY - cornerRadius ? maxY - cornerRadius : sampleY)
                            let dx = sampleX - cx
                            let dy = sampleY - cy
                            sampleInside = (dx * dx + dy * dy <= cr2)
                        }
                        if sampleInside { insideCount += 1.0 }
                    }
                    coverage = insideCount / sampleCount
                }
                // Store the coverage value.
                mask[j * scale + i] = coverage
            }
        }
        return mask
    }
}
