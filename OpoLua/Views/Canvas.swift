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
import UIKit

protocol Drawable: AnyObject {

    func draw(_ operation: Graphics.DrawCommand)
    func setSprite(_ sprite: Graphics.Sprite?, for id: Int)
    func getImage() -> CGImage?

    func updateSprites()

}

class Sprite {

    let sprite: Graphics.Sprite
    var index: Int = 0

    var frame: Graphics.Sprite.Frame {
        return sprite.frames[index]
    }

    init(sprite: Graphics.Sprite) {
        self.sprite = sprite
    }

    func tick() {
        index = index + 1
        if index >= sprite.frames.count {
            index = 0
        }
    }

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
        guard let sprite = sprite else {
            self.sprites.removeValue(forKey: id)
            return
        }
        self.sprites[id] = Sprite(sprite: sprite)
        print(self.sprites)
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
        guard image == nil else {
            return self.image
        }
        UIGraphicsBeginImageContext(self.size)
        defer {
            UIGraphicsEndImageContext()
        }
        guard let context = UIGraphicsGetCurrentContext(),
              let cgImage = self.context.makeImage()
        else {
            return nil
        }
        context.concatenate(context.coordinateFlipTransform)

        // Draw our backing image.
        context.draw(cgImage, in: CGRect(origin: .zero, size: self.size))

        // Draw our sprites.
        // TODO: Check how the CGContext drawing implementations access drawables.
        for sprite in self.sprites.values {
            guard let image = windowServer.drawable(for: sprite.frame.bitmap)?.getImage(),
                  let mask = windowServer.drawable(for: sprite.frame.mask)?.getImage()?.copyInDeviceGrayColorSpace(),
                  let maskedImage = image.masking(mask)
            else {
                continue
            }
            let origin = sprite.sprite.origin + sprite.frame.offset
            let destRect = Graphics.Rect(origin: origin, size: image.size)
            context.draw(maskedImage, in: destRect.cgRect())
        }
        self.image = UIGraphicsGetImageFromCurrentImageContext()?.cgImage

        return self.image
    }

}
