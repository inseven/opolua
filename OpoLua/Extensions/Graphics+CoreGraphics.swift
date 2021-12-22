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

extension Graphics.MaskedBitmap {

    var cgImage: CGImage {
        var img = CGImage.from(bitmap: self.bitmap)
        if let mask = self.mask {
            precondition(bitmap.width == mask.width && bitmap.height == mask.height, "Bad mask size!")
            // CoreGraphics masks have the opposite semantics to epoc ones...
            let maskCg = CGImage.from(bitmap: mask)
            let rect = CGRect(origin: .zero, size: bitmap.size.cgSize())
            let invertedCi = CIImage(cgImage: maskCg).applyingFilter("CIColorInvert")
            let invertedCg = CIContext().createCGImage(invertedCi, from: invertedCi.extent)!
            // invertedCg has an alpha channel (I think) which means masking() doesn't work.
            // There must be a more efficient way to do this...
            let context = CGContext(data: nil,
                                    width: bitmap.width,
                                    height: bitmap.height,
                                    bitsPerComponent: 8,
                                    bytesPerRow: bitmap.width,
                                    space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: 0)!
            context.draw(invertedCg, in: rect)
            let invertedCgNoAlpha = context.makeImage()!
            img = img.masking(invertedCgNoAlpha)!
        }
        return img
    }

}
