// Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import CoreGraphics
import CoreImage

extension CGImage {

    var size: Graphics.Size {
        return Graphics.Size(width: width, height: height)
    }

    var cgSize: CGSize {
        return CGSize(width: width, height: height)
    }

    // This can't be a convenience constructor because that is not allowed in extensions to CFTypes (apparently).
    public static func from(bitmap: Graphics.Bitmap) -> CGImage {
        let provider = CGDataProvider(data: bitmap.normalizedImgData as CFData)!
        if bitmap.isColor {
            let sp = CGColorSpaceCreateDeviceRGB()
            let inf = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            return CGImage(width: bitmap.width, height: bitmap.height,
                bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: bitmap.stride, space: sp,
                bitmapInfo: inf,
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)!
        } else {
            let sp = CGColorSpaceCreateDeviceGray()
            return CGImage(width: bitmap.width, height: bitmap.height,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: bitmap.stride, space: sp,
                bitmapInfo: CGBitmapInfo.byteOrderDefault,
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)!
        }
    }

    func masking(componentRange from: Int, to: Int) -> CGImage? {
        let fromf = CGFloat(from)
        let tof = CGFloat(to)
        let components: [CGFloat]
        if self.bitsPerPixel == 32 {
            components = [fromf, tof, fromf, tof, fromf, tof]
            return self.stripAlpha().copy(maskingColorComponents: components)
        } else if self.bitsPerPixel == 8 {
            components = [fromf, tof]
        } else if self.bitsPerPixel == 16 && (self.bitmapInfo.rawValue & CGImageAlphaInfo.noneSkipLast.rawValue) > 0 {
            components = [fromf, tof]
        } else {
            print("Unhandled bpp in Graphics.Mode.Set image drawing!")
            return nil
        }
        return self.copy(maskingColorComponents: components)
    }

    func stripAlpha(grayscale: Bool = false) -> CGImage {
        let space = grayscale ? CGColorSpaceCreateDeviceGray() : self.colorSpace ?? CGColorSpaceCreateDeviceGray()
        var info: UInt32 = 0
        if !grayscale {
            info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
        }
        let context = CGContext(data: nil,
                                width: self.width,
                                height: self.height,
                                bitsPerComponent: 8,
                                bytesPerRow: self.width * (grayscale ? 1 : (self.bitsPerPixel / 4)),
                                space: space,
                                bitmapInfo: info)!
        let rect = CGRect(x: 0, y: 0, width: self.width, height: self.height)
        context.draw(self, in: rect)
        return context.makeImage()!
    }

    func inverted() -> CGImage? {
        let invertedCi = CIImage(cgImage: self).applyingFilter("CIColorInvert")
        let invertedCG = CIContext().createCGImage(invertedCi, from: invertedCi.extent)
        return invertedCG
    }

    func copyInDeviceGrayColorSpace() -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bytesPerPixel: Int = 1
        let bitmapInfo: UInt32 = 0
        let bytesPerRow = bytesPerPixel * Int(size.width)
        let bitsPerComponent = 8
        guard let context = CGContext(data: nil,
                                      width: Int(size.width == 0 ? 1 : size.width),
                                      height: Int(size.height == 0 ? 1 : size.height),
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo) else {
            return nil
        }
        context.draw(self, in: CGRect(origin: .zero, size: cgSize))
        return context.makeImage()
    }

    func getPixelData() -> UnsafeBufferPointer<UInt32> {
        // This is only valid for images created from Canvases (or otherwise are guaranteed to be using 32bpp)
        precondition(self.bitsPerPixel == 32)
        let data = self.dataProvider!.data!
        let count = CFDataGetLength(data) / 4
        let ptr = UnsafeRawPointer(CFDataGetBytePtr(data)).bindMemory(to: UInt32.self, capacity: count)
        return UnsafeBufferPointer(start: ptr, count: count)
    }

}
