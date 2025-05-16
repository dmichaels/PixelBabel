import SwiftUI
import Utils

extension CellGridView
{
    private static let _colorSpace = CGColorSpaceCreateDeviceRGB()
    private static let _bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue

    public var image: CGImage? {
        var image: CGImage?
        self._buffer.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { fatalError("No buffer base address") }
            if let context: CGContext = CGContext(
                data: baseAddress,
                width: self.viewWidthScaled,
                height: self.viewHeightScaled,
                bitsPerComponent: 8,
                bytesPerRow: self.viewWidthScaled * Screen.depth,
                space: CellGridView._colorSpace,
                bitmapInfo: CellGridView._bitmapInfo
            ) {
                image = context.makeImage()
            }
        }
        return image
    }
}

