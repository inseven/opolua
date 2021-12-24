// Copyright (c) 2021 Jason Morley, Tom Sutcliffe
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

private func scale2bpp(_ val: UInt8) -> UInt8 {
    return val | (val << 2) | (val << 4) | (val << 6)
}

extension CGImage {
    static func from(bitmap: Graphics.Bitmap) throws -> CGImage {
        if bitmap.bpp == 2 || bitmap.bpp == 4 {
            // CoreGraphics doesn't seem to like <8bpp, so expand it
            // (It renders it, it just makes a mess)
            var wdat = Data()
            let stride: Int
            if bitmap.bpp == 2 {
                wdat.reserveCapacity(bitmap.data.count * 4)
                for b in bitmap.data {
                    wdat.append(scale2bpp(b & 0x3))
                    wdat.append(scale2bpp((b & 0xC) >> 2))
                    wdat.append(scale2bpp((b & 0x30) >> 4))
                    wdat.append(scale2bpp((b & 0xC0) >> 6))
                }
                stride = bitmap.stride * 4
            } else {
                wdat.reserveCapacity(bitmap.data.count * 2)
                for b in bitmap.data {
                    wdat.append(((b & 0xF) << 4) | (b & 0xF)) // 0xA -> 0xAA etc
                    wdat.append((b & 0xF0) | (b >> 4)) // 0x0A -> 0xAA etc
                }
                stride = bitmap.stride * 2
            }
            let provider = CGDataProvider(data: wdat as CFData)!
            let sp = CGColorSpaceCreateDeviceGray()
            return CGImage(width: bitmap.size.width, height: bitmap.size.height,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: stride, space: sp,
                bitmapInfo: CGBitmapInfo.byteOrder32Little,
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)!
        } else {
            throw OpoLuaError.unsupportedBitmapDepth(bitmap.bpp)
        }
    }

    func masking(epocMask: CGImage) -> CGImage? {
        precondition(self.width == epocMask.width && self.height == epocMask.height, "Bad mask size!")
        // CoreGraphics masks have the opposite semantics to epoc ones...
        let invertedCi = CIImage(cgImage: epocMask).applyingFilter("CIColorInvert")
        let invertedCg = CIContext().createCGImage(invertedCi, from: invertedCi.extent)!
        // invertedCg has an alpha channel (I think) which means masking() doesn't work.
        // There must be a more efficient way to do this...
        return self.masking(invertedCg.stripAlpha())
    }

    func stripAlpha() -> CGImage {
        let context = CGContext(data: nil,
                                width: self.width,
                                height: self.height,
                                bitsPerComponent: 8,
                                bytesPerRow: self.width,
                                space: CGColorSpaceCreateDeviceGray(),
                                bitmapInfo: 0)!
        let rect = CGRect(x: 0, y: 0, width: self.width, height: self.height)
        context.draw(self, in: rect)
        return context.makeImage()!
    }
}
