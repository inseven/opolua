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

import CoreGraphics
import Foundation

protocol Drawable: AnyObject {

    func draw(_ operation: Graphics.DrawCommand)
    func getImage() -> CGImage?

}

class Canvas: Drawable {

    let size: CGSize
    private var image: CGImage?
    private let context: CGContext

    init(size: CGSize, color: Bool) {
        self.size = size
        let colorSpace: CGColorSpace
        let bytesPerPixel: Int
        let bitmapInfo: UInt32
        if color {
            colorSpace = CGColorSpaceCreateDeviceRGB()
            bytesPerPixel = 4
            bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        } else {
            colorSpace = CGColorSpaceCreateDeviceGray()
            bytesPerPixel = 1
            bitmapInfo = 0
        }
        let bytesPerRow = bytesPerPixel * Int(size.width)
        let bitsPerComponent = 8
        // Apparently zero-width windows are allowed in OPL, who knows why...
        context = CGContext(data: nil,
                            width: Int(size.width == 0 ? 1 : size.width),
                            height: Int(size.height == 0 ? 1 : size.height),
                            bitsPerComponent: bitsPerComponent,
                            bytesPerRow: bytesPerRow,
                            space: colorSpace,
                            bitmapInfo: bitmapInfo)!
        context.concatenate(context.coordinateFlipTransform)
    }

    func draw(_ operation: Graphics.DrawCommand) {
        context.draw(operation)
        self.image = nil
    }

    func getImage() -> CGImage? {
        if self.image == nil {
            self.image = self.context.makeImage()
        }
        return self.image
    }

}
