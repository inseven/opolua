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

import CoreGraphics
import Foundation

import OpoLuaCore

protocol DrawableImageProvider {

    func getDrawable(_ drawable: Graphics.DrawableId) -> Drawable?
    func getDitherImage() -> CGImage

}

protocol Drawable: AnyObject {

    var id: Graphics.DrawableId { get }
    var mode: Graphics.Bitmap.Mode { get }
    var size: Graphics.Size { get }

    func draw(_ operation: Graphics.DrawCommand, provider: DrawableImageProvider) -> Graphics.Error?
    func getImage() -> CGImage?
    func getInvertedMask() -> CGImage?
    func getData() -> UnsafeBufferPointer<UInt32>

}

class Canvas: Drawable {

    let id: Graphics.DrawableId
    let mode: Graphics.Bitmap.Mode
    let size: Graphics.Size
    private var image: CGImage?
    private var mask: CGImage?
    private let context: CGContext
    private var data: UnsafeMutableBufferPointer<UInt32>

    init(id: Graphics.DrawableId, size: Graphics.Size, mode: Graphics.Bitmap.Mode) {
        self.id = id
        self.size = size
        self.mode = mode
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        self.data = .allocate(capacity: size.width * size.height)
        let bytesPerRow = bytesPerPixel * size.width
        let bitsPerComponent = 8
        context = CGContext(data: self.data.baseAddress,
                            width: size.width,
                            height: size.height,
                            bitsPerComponent: bitsPerComponent,
                            bytesPerRow: bytesPerRow,
                            space: colorSpace,
                            bitmapInfo: bitmapInfo)!
        context.concatenate(context.coordinateFlipTransform)
        // All drawables should start off filled with white
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
    }

    func draw(_ operation: Graphics.DrawCommand, provider: DrawableImageProvider) -> Graphics.Error? {
        defer {
            self.image = nil
            self.mask = nil
        }

        return context.draw(operation, buffer: data, provider: provider)
    }

    func draw(image: CGImage) {
        context.draw(image: image)
        self.image = nil
        self.mask = nil
    }

    func getData() -> UnsafeBufferPointer<UInt32> {
        return UnsafeBufferPointer(data)
    }

    func getImage() -> CGImage? {
        if self.image == nil {
            self.image = self.context.makeImage()
        }
        return self.image
    }

    func getInvertedMask() -> CGImage? {
        if self.mask == nil {
            self.mask = getImage()?.inverted()?.masking(componentRange: 0, to: 0)
        }
        return self.mask
    }

    func invertCoordinates(point: Graphics.Point) -> Graphics.Point {
        return Graphics.Point(x: point.x, y: self.size.height - point.y)
    }

    deinit {
        self.data.deallocate()
    }

}
