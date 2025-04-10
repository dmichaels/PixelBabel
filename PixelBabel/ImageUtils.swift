import Foundation
import SwiftUI

class ImageUtils {

    private static let _monochromeCIContext = CIContext(options: nil)
    private static let _monochromeThreshold: CIColorKernel = {
        let source = """
        kernel vec4 thresholdFilter(__sample image, float threshold) {
            float luma = dot(image.rgb, vec3(0.299, 0.587, 0.114));
            float bw = step(threshold, luma);
            return vec4(vec3(bw), 1.0);
        }
        """
        return CIColorKernel(source: source)!
    }()

    static func monochrome(_ input: CGImage, threshold: Float = 0.3) -> CGImage? {
        let ciImage = CIImage(cgImage: input)
        guard let outputImage = ImageUtils._monochromeThreshold.apply(extent: ciImage.extent,
                                                                      arguments: [ciImage, threshold]) else {
            return nil
        }
        return ImageUtils._monochromeCIContext.createCGImage(outputImage, from: outputImage.extent)
    }

    static func grayscale(_ image: CGImage) -> CGImage? {

        let width = image.width
        let height = image.height

        guard let colorSpace = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2) else {
            return nil
        }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()
    }

    static func pixelate(_ image: CGImage, _ targetWidth: Int, _ targetHeight: Int, pixelSize: Int) -> CGImage? {

        guard pixelSize > 0 else {
            return image
        }

        // Step 1: Resize image to target output resolution
        guard let resizedContext = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue
        ) else {
            return nil
        }

        resizedContext.interpolationQuality = .high
        resizedContext.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        guard let resizedImage = resizedContext.makeImage() else {
            return nil
        }

        // Step 2: Downsample to pixelated version
        let blocksWide = (targetWidth + pixelSize) / pixelSize
        let blocksHigh = (targetHeight + pixelSize) / pixelSize

        guard blocksWide > 0, blocksHigh > 0 else {
            return resizedImage
        }

        guard let downsampledContext = CGContext(
            data: nil,
            width: blocksWide,
            height: blocksHigh,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue
            ) else {
            return nil
        }

        downsampledContext.interpolationQuality = .none
        downsampledContext.draw(resizedImage, in: CGRect(x: 0, y: 0, width: blocksWide, height: blocksHigh))

        guard let pixelatedSmall = downsampledContext.makeImage() else {
            return nil
        }

        // Step 3: Upsample pixelated image to full resolution
        guard let upsampledContext = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue
        ) else {
            return nil
        }

        upsampledContext.interpolationQuality = .none
        upsampledContext.draw(pixelatedSmall, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        return upsampledContext.makeImage()
    }
}
