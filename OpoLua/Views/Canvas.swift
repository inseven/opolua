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

import CoreGraphics
import Foundation
import UIKit

protocol Drawable: AnyObject {

    var id: Graphics.DrawableId { get }

    func draw(_ operation: Graphics.DrawCommand)
    func setSprite(_ sprite: Graphics.Sprite?, for id: Int)
    func getImage() -> CGImage?

    func updateSprites()

}

class Canvas: Drawable {

    let id: Graphics.DrawableId
    let size: CGSize
    private var image: CGImage?
    private let context: CGContext

    var windowServer: WindowServer

    var sprites: [Int: Sprite] = [:]

    init(windowServer: WindowServer, id: Graphics.DrawableId, size: CGSize, color: Bool) {
        self.windowServer = windowServer
        self.id = id
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
        // All drawables should start off filled with white
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
    }

    func draw(_ operation: Graphics.DrawCommand) {
        context.draw(operation)
        self.image = nil
    }

    func setSprite(_ sprite: Graphics.Sprite?, for id: Int) {
        if let sprite = sprite {
            self.sprites[id] = Sprite(sprite: sprite)
        } else {
            self.sprites.removeValue(forKey: id)
        }
        // print(self.sprites)
        self.image = nil
    }

    func updateSprites() {
        guard !sprites.isEmpty else {
            return
        }
        for sprite in self.sprites.values {
            sprite.tick()
        }
        self.image = nil
    }

    func getImage() -> CGImage? {

        // Return the cached image.
        if image != nil {
            return self.image
        }

        // Render the context.
        guard let cgImage = self.context.makeImage() else {
            return nil
        }

        // Check to see if we have any active sprites; if not, then we can stop here.
        if sprites.isEmpty {
            self.image = cgImage
            return cgImage
        }

        // If our window contains any sprites, we composite these into a secondary context.
        guard let context = CGContext(data: nil,
                                      width: context.width,
                                      height: context.height,
                                      bitsPerComponent: context.bitsPerComponent,
                                      bytesPerRow: context.bytesPerRow,
                                      space: context.colorSpace!,
                                      bitmapInfo: context.bitmapInfo.rawValue) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(origin: .zero, size: cgImage.cgSize))
        for sprite in self.sprites.values {
            guard let image = windowServer.drawable(for: sprite.frame.bitmap)?.getImage(),
                  let mask = windowServer.drawable(for: sprite.frame.mask)?.getImage()
            else {
                continue
            }
            let maskedImage: CGImage
            if sprite.frame.invertMask {
                guard let inverted = mask.inverted(),
                      let invertedGray = inverted.copyInDeviceGrayColorSpace(),
                      let result = image.masking(invertedGray) else {
                        continue
                }
                maskedImage = result
            } else {
                guard let maskGray = mask.copyInDeviceGrayColorSpace(),
                      let result = image.masking(maskGray) else {
                        continue
                }
                maskedImage = result
            }

            let origin = self.invertCoordinates(point: sprite.sprite.origin + sprite.frame.offset)
            let adjustedOrigin = origin - Graphics.Point(x: 0, y: image.size.height)
            let destRect = Graphics.Rect(origin: adjustedOrigin, size: image.size)
            context.draw(maskedImage, in: destRect.cgRect())
        }
        self.image = context.makeImage()

        return self.image
    }

    func invertCoordinates(point: Graphics.Point) -> Graphics.Point {
        return Graphics.Point(x: point.x, y: Int(self.size.height) - point.y)
    }

}
