import SwiftUI
import Utils

extension CellGridView
{
    public var image: CGImage? {
        var image: CGImage?
        self._buffer.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { fatalError("No buffer base address") }
            if let context: CGContext = CGContext(
                data: baseAddress,
                width: self.scaled(self.viewWidth),
                height: self.scaled(self.viewHeight),
                bitsPerComponent: 8,
                bytesPerRow: self.scaled(self.viewWidth) * Screen.depth,
                space: CellGrid.Defaults.colorSpace,
                bitmapInfo: CellGrid.Defaults.bitmapInfo
            ) {
                image = context.makeImage()
            }
        }
        return image
    }
}

