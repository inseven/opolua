// Copyright (c) 2021-2022 Jason Morley, Tom Sutcliffe
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

private let kEpoc4bitPalette: [UInt8] = [
    0x00, 0x00, 0x00, // 0 Black
    0x55, 0x55, 0x55, // 1 Dark grey
    0x80, 0x00, 0x00, // 2 Dark red
    0x80, 0x80, 0x00, // 3 Dark yellow
    0x00, 0x80, 0x00, // 4 Dark green
    0xFF, 0x00, 0x00, // 5 Red
    0xFF, 0xFF, 0x00, // 6 Yellow
    0x00, 0xFF, 0x00, // 7 Green
    0xFF, 0x00, 0xFF, // 8 Magenta
    0x00, 0x00, 0xFF, // 9 Blue
    0x00, 0xFF, 0xFF, // A Cyan
    0x80, 0x00, 0x80, // B Dark magenta
    0x00, 0x00, 0x80, // C Dark blue
    0x00, 0x80, 0x80, // D Dark cyan
    0xAA, 0xAA, 0xAA, // E Light grey
    0xFF, 0xFF, 0xFF, // F White
]

private let kEpoc8bitPalette: [UInt8] = [
    0x00, 0x00, 0x00, // 00
    0x33, 0x00, 0x00, // 01
    0x66, 0x00, 0x00, // 02
    0x99, 0x00, 0x00, // 03
    0xCC, 0x00, 0x00, // 04
    0xFF, 0x00, 0x00, // 05
    0x00, 0x33, 0x00, // 06
    0x33, 0x33, 0x00, // 07
    0x66, 0x33, 0x00, // 08
    0x99, 0x33, 0x00, // 09
    0xCC, 0x33, 0x00, // 0A
    0xFF, 0x33, 0x00, // 0B
    0x00, 0x66, 0x00, // 0C
    0x33, 0x66, 0x00, // 0D
    0x66, 0x66, 0x00, // 0E
    0x99, 0x66, 0x00, // 0F
    0xCC, 0x66, 0x00, // 10
    0xFF, 0x66, 0x00, // 11
    0x00, 0x99, 0x00, // 12
    0x33, 0x99, 0x00, // 13
    0x66, 0x99, 0x00, // 14
    0x99, 0x99, 0x00, // 15
    0xCC, 0x99, 0x00, // 16
    0xFF, 0x99, 0x00, // 17
    0x00, 0xCC, 0x00, // 18
    0x33, 0xCC, 0x00, // 19
    0x66, 0xCC, 0x00, // 1A
    0x99, 0xCC, 0x00, // 1B
    0xCC, 0xCC, 0x00, // 1C
    0xFF, 0xCC, 0x00, // 1D
    0x00, 0xFF, 0x00, // 1E
    0x33, 0xFF, 0x00, // 1F
    0x66, 0xFF, 0x00, // 20
    0x99, 0xFF, 0x00, // 21
    0xCC, 0xFF, 0x00, // 22
    0xFF, 0xFF, 0x00, // 23
    0x00, 0x00, 0x33, // 24
    0x33, 0x00, 0x33, // 25
    0x66, 0x00, 0x33, // 26
    0x99, 0x00, 0x33, // 27
    0xCC, 0x00, 0x33, // 28
    0xFF, 0x00, 0x33, // 29
    0x00, 0x33, 0x33, // 2A
    0x33, 0x33, 0x33, // 2B
    0x66, 0x33, 0x33, // 2C
    0x99, 0x33, 0x33, // 2D
    0xCC, 0x33, 0x33, // 2E
    0xFF, 0x33, 0x33, // 2F
    0x00, 0x66, 0x33, // 30
    0x33, 0x66, 0x33, // 31
    0x66, 0x66, 0x33, // 32
    0x99, 0x66, 0x33, // 33
    0xCC, 0x66, 0x33, // 34
    0xFF, 0x66, 0x33, // 35
    0x00, 0x99, 0x33, // 36
    0x33, 0x99, 0x33, // 37
    0x66, 0x99, 0x33, // 38
    0x99, 0x99, 0x33, // 39
    0xCC, 0x99, 0x33, // 3A
    0xFF, 0x99, 0x33, // 3B
    0x00, 0xCC, 0x33, // 3C
    0x33, 0xCC, 0x33, // 3D
    0x66, 0xCC, 0x33, // 3E
    0x99, 0xCC, 0x33, // 3F
    0xCC, 0xCC, 0x33, // 40
    0xFF, 0xCC, 0x33, // 41
    0x00, 0xFF, 0x33, // 42
    0x33, 0xFF, 0x33, // 43
    0x66, 0xFF, 0x33, // 44
    0x99, 0xFF, 0x33, // 45
    0xCC, 0xFF, 0x33, // 46
    0xFF, 0xFF, 0x33, // 47
    0x00, 0x00, 0x66, // 48
    0x33, 0x00, 0x66, // 49
    0x66, 0x00, 0x66, // 4A
    0x99, 0x00, 0x66, // 4B
    0xCC, 0x00, 0x66, // 4C
    0xFF, 0x00, 0x66, // 4D
    0x00, 0x33, 0x66, // 4E
    0x33, 0x33, 0x66, // 4F
    0x66, 0x33, 0x66, // 50
    0x99, 0x33, 0x66, // 51
    0xCC, 0x33, 0x66, // 52
    0xFF, 0x33, 0x66, // 53
    0x00, 0x66, 0x66, // 54
    0x33, 0x66, 0x66, // 55
    0x66, 0x66, 0x66, // 56
    0x99, 0x66, 0x66, // 57
    0xCC, 0x66, 0x66, // 58
    0xFF, 0x66, 0x66, // 59
    0x00, 0x99, 0x66, // 5A
    0x33, 0x99, 0x66, // 5B
    0x66, 0x99, 0x66, // 5C
    0x99, 0x99, 0x66, // 5D
    0xCC, 0x99, 0x66, // 5E
    0xFF, 0x99, 0x66, // 5F
    0x00, 0xCC, 0x66, // 60
    0x33, 0xCC, 0x66, // 61
    0x66, 0xCC, 0x66, // 62
    0x99, 0xCC, 0x66, // 63
    0xCC, 0xCC, 0x66, // 64
    0xFF, 0xCC, 0x66, // 65
    0x00, 0xFF, 0x66, // 66
    0x33, 0xFF, 0x66, // 67
    0x66, 0xFF, 0x66, // 68
    0x99, 0xFF, 0x66, // 69
    0xCC, 0xFF, 0x66, // 6A
    0xFF, 0xFF, 0x66, // 6B
    0x11, 0x11, 0x11, // 6C
    0x22, 0x22, 0x22, // 6D
    0x44, 0x44, 0x44, // 6E
    0x55, 0x55, 0x55, // 6F
    0x77, 0x77, 0x77, // 70
    0x11, 0x00, 0x00, // 71
    0x22, 0x00, 0x00, // 72
    0x44, 0x00, 0x00, // 73
    0x55, 0x00, 0x00, // 74
    0x77, 0x00, 0x00, // 75
    0x00, 0x11, 0x00, // 76
    0x00, 0x22, 0x00, // 77
    0x00, 0x44, 0x00, // 78
    0x00, 0x55, 0x00, // 79
    0x00, 0x77, 0x00, // 7A
    0x00, 0x00, 0x11, // 7B
    0x00, 0x00, 0x22, // 7C
    0x00, 0x00, 0x44, // 7D
    0x00, 0x00, 0x55, // 7E
    0x00, 0x00, 0x77, // 7F
    0x00, 0x00, 0x88, // 80
    0x00, 0x00, 0xAA, // 81
    0x00, 0x00, 0xBB, // 82
    0x00, 0x00, 0xDD, // 83
    0x00, 0x00, 0xEE, // 84
    0x00, 0x88, 0x00, // 85
    0x00, 0xAA, 0x00, // 86
    0x00, 0xBB, 0x00, // 87
    0x00, 0xDD, 0x00, // 88
    0x00, 0xEE, 0x00, // 89
    0x88, 0x00, 0x00, // 8A
    0xAA, 0x00, 0x00, // 8B
    0xBB, 0x00, 0x00, // 8C
    0xDD, 0x00, 0x00, // 8D
    0xEE, 0x00, 0x00, // 8E
    0x88, 0x88, 0x88, // 8F
    0xAA, 0xAA, 0xAA, // 90
    0xBB, 0xBB, 0xBB, // 91
    0xDD, 0xDD, 0xDD, // 92
    0xEE, 0xEE, 0xEE, // 93
    0x00, 0x00, 0x99, // 94
    0x33, 0x00, 0x99, // 95
    0x66, 0x00, 0x99, // 96
    0x99, 0x00, 0x99, // 97
    0xCC, 0x00, 0x99, // 98
    0xFF, 0x00, 0x99, // 99
    0x00, 0x33, 0x99, // 9A
    0x33, 0x33, 0x99, // 9B
    0x66, 0x33, 0x99, // 9C
    0x99, 0x33, 0x99, // 9D
    0xCC, 0x33, 0x99, // 9E
    0xFF, 0x33, 0x99, // 9F
    0x00, 0x66, 0x99, // A0
    0x33, 0x66, 0x99, // A1
    0x66, 0x66, 0x99, // A2
    0x99, 0x66, 0x99, // A3
    0xCC, 0x66, 0x99, // A4
    0xFF, 0x66, 0x99, // A5
    0x00, 0x99, 0x99, // A6
    0x33, 0x99, 0x99, // A7
    0x66, 0x99, 0x99, // A8
    0x99, 0x99, 0x99, // A9
    0xCC, 0x99, 0x99, // AA
    0xFF, 0x99, 0x99, // AB
    0x00, 0xCC, 0x99, // AC
    0x33, 0xCC, 0x99, // AD
    0x66, 0xCC, 0x99, // AE
    0x99, 0xCC, 0x99, // AF
    0xCC, 0xCC, 0x99, // B0
    0xFF, 0xCC, 0x99, // B1
    0x00, 0xFF, 0x99, // B2
    0x33, 0xFF, 0x99, // B3
    0x66, 0xFF, 0x99, // B4
    0x99, 0xFF, 0x99, // B5
    0xCC, 0xFF, 0x99, // B6
    0xFF, 0xFF, 0x99, // B7
    0x00, 0x00, 0xCC, // B8
    0x33, 0x00, 0xCC, // B9
    0x66, 0x00, 0xCC, // BA
    0x99, 0x00, 0xCC, // BB
    0xCC, 0x00, 0xCC, // BC
    0xFF, 0x00, 0xCC, // BD
    0x00, 0x33, 0xCC, // BE
    0x33, 0x33, 0xCC, // BF
    0x66, 0x33, 0xCC, // C0
    0x99, 0x33, 0xCC, // C1
    0xCC, 0x33, 0xCC, // C2
    0xFF, 0x33, 0xCC, // C3
    0x00, 0x66, 0xCC, // C4
    0x33, 0x66, 0xCC, // C5
    0x66, 0x66, 0xCC, // C6
    0x99, 0x66, 0xCC, // C7
    0xCC, 0x66, 0xCC, // C8
    0xFF, 0x66, 0xCC, // C9
    0x00, 0x99, 0xCC, // CA
    0x33, 0x99, 0xCC, // CB
    0x66, 0x99, 0xCC, // CC
    0x99, 0x99, 0xCC, // CD
    0xCC, 0x99, 0xCC, // CE
    0xFF, 0x99, 0xCC, // CF
    0x00, 0xCC, 0xCC, // D0
    0x33, 0xCC, 0xCC, // D1
    0x66, 0xCC, 0xCC, // D2
    0x99, 0xCC, 0xCC, // D3
    0xCC, 0xCC, 0xCC, // D4
    0xFF, 0xCC, 0xCC, // D5
    0x00, 0xFF, 0xCC, // D6
    0x33, 0xFF, 0xCC, // D7
    0x66, 0xFF, 0xCC, // D8
    0x99, 0xFF, 0xCC, // D9
    0xCC, 0xFF, 0xCC, // DA
    0xFF, 0xFF, 0xCC, // DB
    0x00, 0x00, 0xFF, // DC
    0x33, 0x00, 0xFF, // DD
    0x66, 0x00, 0xFF, // DE
    0x99, 0x00, 0xFF, // DF
    0xCC, 0x00, 0xFF, // E0
    0xFF, 0x00, 0xFF, // E1
    0x00, 0x33, 0xFF, // E2
    0x33, 0x33, 0xFF, // E3
    0x66, 0x33, 0xFF, // E4
    0x99, 0x33, 0xFF, // E5
    0xCC, 0x33, 0xFF, // E6
    0xFF, 0x33, 0xFF, // E7
    0x00, 0x66, 0xFF, // E8
    0x33, 0x66, 0xFF, // E9
    0x66, 0x66, 0xFF, // EA
    0x99, 0x66, 0xFF, // EB
    0xCC, 0x66, 0xFF, // EC
    0xFF, 0x66, 0xFF, // ED
    0x00, 0x99, 0xFF, // EE
    0x33, 0x99, 0xFF, // EF
    0x66, 0x99, 0xFF, // F0
    0x99, 0x99, 0xFF, // F1
    0xCC, 0x99, 0xFF, // F2
    0xFF, 0x99, 0xFF, // F3
    0x00, 0xCC, 0xFF, // F4
    0x33, 0xCC, 0xFF, // F5
    0x66, 0xCC, 0xFF, // F6
    0x99, 0xCC, 0xFF, // F7
    0xCC, 0xCC, 0xFF, // F8
    0xFF, 0xCC, 0xFF, // F9
    0x00, 0xFF, 0xFF, // FA
    0x33, 0xFF, 0xFF, // FB
    0x66, 0xFF, 0xFF, // FC
    0x99, 0xFF, 0xFF, // FD
    0xCC, 0xFF, 0xFF, // FE
    0xFF, 0xFF, 0xFF, // FF
]

extension CGImage {

    var size: Graphics.Size {
        return Graphics.Size(width: width, height: height)
    }

    var cgSize: CGSize {
        return CGSize(width: width, height: height)
    }

    // TODO: This should be a convenience constructor
    static func from(bitmap: Graphics.Bitmap) -> CGImage {
        switch bitmap.mode {
        case .gray2, .gray4, .gray16:
            // CoreGraphics doesn't seem to like <8bpp, so expand it
            // (It renders it, it just makes a mess)
            var wdat = Data()
            let stride: Int
            if bitmap.mode == .gray2 {
                wdat.reserveCapacity(bitmap.data.count * 8)
                for b in bitmap.data {
                    for i in 0 ..< 8 {
                        wdat.append(((b >> i) & 1) == 1 ? 0xFF : 0)
                    }
                }
                stride = bitmap.stride * 8
            } else if bitmap.mode == .gray4 {
                wdat.reserveCapacity(bitmap.data.count * 4)
                for b in bitmap.data {
                    wdat.append(scale2bpp(b & 0x3))
                    wdat.append(scale2bpp((b & 0xC) >> 2))
                    wdat.append(scale2bpp((b & 0x30) >> 4))
                    wdat.append(scale2bpp((b & 0xC0) >> 6))
                }
                stride = bitmap.stride * 4
            } else {
                // 4bpp
                wdat.reserveCapacity(bitmap.data.count * 2)
                for b in bitmap.data {
                    wdat.append(((b & 0xF) << 4) | (b & 0xF)) // 0xA -> 0xAA etc
                    wdat.append((b & 0xF0) | (b >> 4)) // 0x0A -> 0xAA etc
                }
                stride = bitmap.stride * 2
            }
            let provider = CGDataProvider(data: wdat as CFData)!
            let sp = CGColorSpaceCreateDeviceGray()
            return CGImage(width: bitmap.width, height: bitmap.height,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: stride, space: sp,
                bitmapInfo: CGBitmapInfo.byteOrder32Little,
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)!
        case .gray256:
            let provider = CGDataProvider(data: bitmap.data as CFData)!
            let sp = CGColorSpaceCreateDeviceGray()
            return CGImage(width: bitmap.width, height: bitmap.height,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: bitmap.stride, space: sp,
                bitmapInfo: CGBitmapInfo.byteOrder32Little,
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)!
        case .color16:
            var wdat = Data()
            wdat.reserveCapacity(bitmap.data.count * 2)
            for b in bitmap.data {
                wdat.append(b & 0xF)
                wdat.append(b >> 4)
            }
            let provider = CGDataProvider(data: wdat as CFData)!
            let sp = CGColorSpace(indexedBaseSpace: CGColorSpaceCreateDeviceRGB(), last: 15, colorTable: kEpoc4bitPalette)!
            let inf = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            return CGImage(width: bitmap.width, height: bitmap.height,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: bitmap.stride * 2, space: sp,
                bitmapInfo: inf,
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)!
        case .color256:
            let provider = CGDataProvider(data: bitmap.data as CFData)!
            let sp = CGColorSpace(indexedBaseSpace: CGColorSpaceCreateDeviceRGB(), last: 255, colorTable: kEpoc8bitPalette)!
            let inf = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            return CGImage(width: bitmap.width, height: bitmap.height,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: bitmap.stride, space: sp,
                bitmapInfo: inf,
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)!
        case .color64K:
            let provider = CGDataProvider(data: bitmap.data as CFData)!
            let sp = CGColorSpaceCreateDeviceRGB()
            let inf = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            return CGImage(width: bitmap.width, height: bitmap.height,
                bitsPerComponent: 16, bitsPerPixel: 16, // bitsPerComponent is probably wrong here
                bytesPerRow: bitmap.stride, space: sp,
                bitmapInfo: inf,
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)!
        case .color16M:
            let provider = CGDataProvider(data: bitmap.data as CFData)!
            let sp = CGColorSpaceCreateDeviceRGB()
            let inf = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            return CGImage(width: bitmap.width, height: bitmap.height,
                bitsPerComponent: 8, bitsPerPixel: 24,
                bytesPerRow: bitmap.stride, space: sp,
                bitmapInfo: inf,
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)!
        }
    }

    func masking(epocMask: CGImage) -> CGImage? {
        precondition(self.width == epocMask.width && self.height == epocMask.height, "Bad mask size!")
        // CoreGraphics masks have the opposite semantics to epoc ones...
        let invertedCi = CIImage(cgImage: epocMask).applyingFilter("CIColorInvert")
        let invertedCg = CIContext().createCGImage(invertedCi, from: invertedCi.extent)!
        // invertedCg has an alpha channel (I think) which means masking() doesn't work.
        // There must be a more efficient way to do this...
        return self.masking(invertedCg.stripAlpha(grayscale: true))
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

}
