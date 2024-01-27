// Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe
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
import UIKit

protocol DrawableImageProvider {

    func getImageFor(drawable: Graphics.DrawableId) -> CGImage?

}

protocol Drawable: AnyObject {

    var id: Graphics.DrawableId { get }
    var mode: Graphics.Bitmap.Mode { get }

    func draw(_ operation: Graphics.DrawCommand, provider: DrawableImageProvider)
    func getImage() -> CGImage?

}

class Canvas: Drawable {

    let id: Graphics.DrawableId
    let mode: Graphics.Bitmap.Mode
    let size: CGSize
    private var image: CGImage?
    private let context: CGContext

    init(id: Graphics.DrawableId, size: CGSize, mode: Graphics.Bitmap.Mode) {
        self.id = id
        self.size = size
        self.mode = mode
        let colorSpace: CGColorSpace
        let bytesPerPixel: Int
        let bitmapInfo: UInt32
        if mode.isColor {
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
        // All drawables should start off filled with white
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
    }

    func draw(_ operation: Graphics.DrawCommand, provider: DrawableImageProvider) {
        context.draw(operation, provider: provider)
        self.image = nil
    }

    func draw(image: CGImage) {
        context.draw(image: image)
        self.image = nil
    }

    func getImage() -> CGImage? {
        if self.image == nil {
            self.image = self.context.makeImage()
        }
        return self.image
    }

    func invertCoordinates(point: Graphics.Point) -> Graphics.Point {
        return Graphics.Point(x: point.x, y: Int(self.size.height) - point.y)
    }

}
