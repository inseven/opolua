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
    let size: Graphics.Size
    private var image: CGImage?
    private let context: CGContext
    private var data: UnsafeMutableRawBufferPointer?

    init(id: Graphics.DrawableId, size: Graphics.Size, mode: Graphics.Bitmap.Mode) {
        self.id = id
        self.size = size
        self.mode = mode
        let colorSpace: CGColorSpace
        let bytesPerPixel: Int
        let bitmapInfo: UInt32
        // Apparently zero-width windows are allowed in OPL, who knows why...
        let intw = size.width == 0 ? 1 : size.width
        let inth = size.height == 0 ? 1 : size.height
        if mode.isColor {
            colorSpace = CGColorSpaceCreateDeviceRGB()
            bytesPerPixel = 4
            bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            self.data = nil
        } else {
            colorSpace = CGColorSpaceCreateDeviceGray()
            bytesPerPixel = 1
            bitmapInfo = 0
            self.data = .allocate(byteCount: intw * inth, alignment: 8)
        }
        let bytesPerRow = bytesPerPixel * intw
        let bitsPerComponent = 8
        context = CGContext(data: self.data?.baseAddress,
                            width: intw,
                            height: inth,
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
        if data != nil && operation.mode == .invert {
            drawInverted(operation: operation, provider: provider)
        } else if data != nil, case .invert(_) = operation.type {
            drawInverted(operation: operation, provider: provider)
        } else {
            context.draw(operation, provider: provider)
        }
        self.image = nil
    }

    func draw(image: CGImage) {
        context.draw(image: image)
        self.image = nil
    }

    func xorPixel(_ x: Int, _ y: Int, _ val: UInt8) {
        if x >= 0 && x < size.width && y >= 0 && y < size.height {
            let data = self.data!
            let pos = size.width * y + x
            data[pos] = data[pos] ^ val
        }
    }

    // Only supported when using 8bpp greyscale backing data
    func drawInverted(operation: Graphics.DrawCommand, provider: DrawableImageProvider) {
        let byteVal = ~operation.color.greyValue
        switch operation.type {
        case .fill(let size):
            for y in 0 ..< size.height {
                for x in 0 ..< size.width {
                    xorPixel(operation.origin.x + x, operation.origin.y + y, byteVal)
                }
            }
        case .invert(let size):
            for y in 0 ..< size.height {
                for x in 0 ..< size.width {
                    if (x == 0 || x == size.width - 1) && (y == 0 || y == size.height - 1) {
                        // gINVERT doesn't draw corner pixels
                    } else {
                        xorPixel(operation.origin.x + x, operation.origin.y + y, byteVal)
                    }
                }
            }
        case .copy(let src, _): // Mask is never used in gCOPY, only in gBUTTON impl which doesn't use invert
            guard let srcImg = provider.getImageFor(drawable: src.drawableId) else {
                print("Failed to get image for .copy operation!")
                return
            }
            // Hopefully don't have to deal with downscaling a colour bitmap into a greyscale canvas...
            assert(srcImg.bitsPerPixel == 8)

            let srcPtr = CFDataGetBytePtr(srcImg.dataProvider!.data!)!
            let srcStride = srcImg.bytesPerRow

            // OPL lets your src rect extend beyond the top and left of the
            // image, in which case we need to adjust the dest pos
            var srcRect = src.rect
            var destX = operation.origin.x
            var destY = operation.origin.y
            if srcRect.minX < 0 {
                destX = destX - src.rect.minX
                srcRect = Graphics.Rect(x: 0, y: srcRect.minY, width: srcRect.width + srcRect.minX, height: srcRect.height)
            }
            if srcRect.minY < 0 {
                destY = destY - src.rect.minY
                srcRect = Graphics.Rect(x: srcRect.minX, y: 0, width: srcRect.width, height: srcRect.height + srcRect.minY)
            }

            for y in 0 ..< srcRect.height {
                for x in 0 ..< srcRect.width {
                    let srcPx = srcPtr[srcStride * (srcRect.minY + y) + srcRect.minX + x]
                    xorPixel(destX + x, destY + y, ~srcPx)
                }
            }
        case .line(let endPoint):
            drawLineInverted(x0: operation.origin.x, y0: operation.origin.y, x1: endPoint.x, y1: endPoint.y, value: byteVal)
        case .box(let size):
            let topLeft = operation.origin
            drawLineInverted(x0: topLeft.x, y0: topLeft.y, x1: topLeft.x + size.width, y1: topLeft.y, value: byteVal) // top
            drawLineInverted(x0: topLeft.x + size.width, y0: topLeft.y, x1: topLeft.x + size.width, y1: topLeft.y + size.height, value: byteVal) // right
            drawLineInverted(x0: topLeft.x + size.width, y0: topLeft.y + size.height, x1: topLeft.x, y1: topLeft.y + size.height, value: byteVal) // bottom
            drawLineInverted(x0: topLeft.x, y0: topLeft.y + size.height, x1: topLeft.x, y1: topLeft.y, value: byteVal) // bottom
        default:
            print("TODO: drawInverted \(operation.type)")
            context.draw(operation, provider: provider)
        }
    }

    func getImage() -> CGImage? {
        if self.image == nil {
            self.image = self.context.makeImage()
        }
        return self.image
    }

    func invertCoordinates(point: Graphics.Point) -> Graphics.Point {
        return Graphics.Point(x: point.x, y: self.size.height - point.y)
    }

    deinit {
        self.data?.deallocate()
    }

    // From bitmap_drawLine() in https://github.com/tomsci/lupi/blob/master/modules/bitmap/bitmap.c
    func drawLineInverted(x0: Int, y0: Int, x1: Int, y1: Int, value: UInt8) {
        let dx = x1 - x0
        let dy = y1 - y0
        // "scan" is the axis we iterate over (x in quadrant 0)
        // "inc" is the axis we conditionally add to (y in quadrant 0)
        var inc: Int = 0
        var scan: Int = 0
        let incr: Int
        let scanStart: Int
        let scanEnd: Int
        let scanIncr: Int
        var dscan: Int
        var dinc: Int
        let drawXY: () -> Void
        if abs(dx) > abs(dy) {
            drawXY = {
                self.xorPixel(scan, inc, value)
            }
            dscan = dx
            dinc = dy
            inc = y0
            scanStart = x0 + 1
            scanEnd = x1
        } else {
            drawXY = {
                self.xorPixel(inc, scan, value)
            }
            dscan = dy
            dinc = dx
            inc = x0
            scanStart = y0 + 1
            scanEnd = y1
        }

        if (dinc < 0) {
            incr = -1
            dinc = -dinc
        } else {
            incr = 1
        }
        if (dscan < 0) {
            scanIncr = -1
            dscan = -dscan
        } else {
            scanIncr = 1
        }
        // Hoist these as they're constants
        let TwoDinc = 2 * dinc
        let TwoDincMinusTwoDscan = 2 * dinc - 2 * dscan

        var D = TwoDinc - dscan
        xorPixel(x0, y0, 0xFF)
        // OPL does not draw the end pixel of a line
        // xorPixel(x1, y1, 0xFF)

        scan = scanStart
        while scan != scanEnd {
            if (D > 0) {
                inc = inc + incr
                drawXY()
                D = D + TwoDincMinusTwoDscan
            } else {
                drawXY()
                D = D + TwoDinc
            }
            scan = scan + scanIncr
        }
    }
}
