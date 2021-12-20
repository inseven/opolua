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

private func scale2bpp(_ val: UInt8) -> UInt8 {
    return val | (val << 2) | (val << 4) | (val << 6)
}

extension CGImage {
    static func from(pixelData: Graphics.PixelData) -> CGImage {
        if pixelData.bpp == 2 || pixelData.bpp == 4 {
            // CoreGraphics doesn't seem to like <8bpp, so expand it
            // (It renders it, it just makes a mess)
            var wdat = Data()
            let stride: Int
            if pixelData.bpp == 2 {
                wdat.reserveCapacity(pixelData.data.count * 4)
                for b in pixelData.data {
                    wdat.append(scale2bpp(b & 0x3))
                    wdat.append(scale2bpp((b & 0xC) >> 2))
                    wdat.append(scale2bpp((b & 0x30) >> 4))
                    wdat.append(scale2bpp((b & 0xC0) >> 6))
                }
                stride = pixelData.stride * 4
            } else {
                wdat.reserveCapacity(pixelData.data.count * 2)
                for b in pixelData.data {
                    wdat.append(((b & 0xF) << 4) | (b & 0xF)) // 0xA -> 0xAA etc
                    wdat.append((b & 0xF0) | (b >> 4)) // 0x0A -> 0xAA etc
                }
                stride = pixelData.stride * 2
            }
            let provider = CGDataProvider(data: wdat as CFData)!
            let sp = CGColorSpaceCreateDeviceGray()
            return CGImage(width: pixelData.size.width, height: pixelData.size.height,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: stride, space: sp,
                bitmapInfo: CGBitmapInfo.byteOrder32Little,
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)!
        } else {
            fatalError("Unsupported bpp \(pixelData.bpp)")
        }
    }
}
