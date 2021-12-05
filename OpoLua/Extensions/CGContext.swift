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
import UIKit

extension CGContext {

    var coordinateFlipTransform: CGAffineTransform {
        return CGAffineTransform(scaleX: 1.0, y: -1.0).translatedBy(x: 0.0, y: -CGFloat(self.height))
    }

    func draw(_ operation: Graphics.DrawCommand) {
        // TODO: Scale for the iOS screensize
        let col: CGColor
        if operation.mode == .clear {
            col = operation.bgcolor.cgColor()
        } else {
            // TODO: not handling mode == .invert here...
            col = operation.color.cgColor()
        }
        setStrokeColor(col)
        setFillColor(col)
        switch operation.type {
        case .fill(let size):
            fill(CGRect(origin: operation.origin.cgPoint(), size: size.cgSize()))
        case .circle(let radius, let fill):
            let rect = CGRect(x: operation.origin.x - radius,
                              y: operation.origin.y - radius,
                              width: radius * 2,
                              height: radius * 2)
            addEllipse(in: rect)
            if fill {
                fillPath()
            } else {
                strokePath()
            }
        case .ellipse(let hRadius, let vRadius, let fill):
            let rect = CGRect(x: operation.origin.x - hRadius,
                              y: operation.origin.y - vRadius,
                              width: hRadius * 2,
                              height: vRadius * 2)
            addEllipse(in: rect)
            if fill {
                fillPath()
            } else {
                strokePath()
            }
        case .line(let endPoint):
            let path = CGMutablePath()
            path.move(to: operation.origin.cgPoint().move(x: 0.5, y: 0.5))
            path.addLine(to: endPoint.cgPoint().move(x: -0.5, y: -0.5))
            addPath(path)
            strokePath()
        case .box(let size):
            let rect = CGRect(origin: operation.origin.cgPoint().move(x: 0.5, y: 0.5),
                              size: size.cgSize().adding(dx: -1, dy: -1))
            addPath(CGPath(rect: rect, transform: nil))
            strokePath()
        case .bitblt(let pxInfo):
            if pxInfo.bpp == 4 {
                // CoreGraphics doesn't seem to like 4bpp, so expand it
                var wdat = Data()
                wdat.reserveCapacity(pxInfo.data.count * 2)
                for b in pxInfo.data {
                    wdat.append(((b & 0xF) << 4) | (b & 0xF)) // 0xA -> 0xAA etc
                    wdat.append((b & 0xF0) | (b >> 4)) // 0x0A -> 0xAA etc
                }
                let provider = CGDataProvider(data: wdat as CFData)!
                let sp = CGColorSpaceCreateDeviceGray()
                let cgImg = CGImage(width: pxInfo.size.width, height: pxInfo.size.height,
                    bitsPerComponent: 8, bitsPerPixel: 8,
                    bytesPerRow: pxInfo.stride * 2, space: sp,
                    bitmapInfo: CGBitmapInfo.byteOrder32Little,
                    provider: provider, decode: nil, shouldInterpolate: false,
                    intent: .defaultIntent)!
                drawUnflippedImage(cgImg, in: CGRect(origin: operation.origin.cgPoint(), size: pxInfo.size.cgSize()))
            } else {
                print("Unhandled bpp \(pxInfo.bpp) in bitblt operation!")
            }
        case .copy(let src):
            guard let srcDrawable = src.extra as? Drawable, let srcImage = srcDrawable.image else {
                print("Couldn't get source drawable from extra!")
                return
            }
            if let img = srcImage.cropping(to: src.rect.cgRect()) {
                drawUnflippedImage(img, in: CGRect(origin: operation.origin.cgPoint(), size: src.rect.size.cgSize()))
            }
        case .scroll(let dx, let dy, let rect):
            let origRect = rect.cgRect()
            if let img = makeImage()?.cropping(to: origRect) {
                let newRect = CGRect(x: rect.minX + dx, y: rect.minY + dy, width: rect.width, height: rect.height).standardized
                // This is not entirely the right logic if both dx and dy are non-zero, but probably good enough for now
                let minX = min(origRect.minX, newRect.minX)
                let minY = min(origRect.minY, newRect.minY)
                let maxX = max(origRect.maxX, newRect.maxX)
                let maxY = max(origRect.maxY, newRect.maxY)
                let clearRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).standardized
                setFillColor(operation.bgcolor.cgColor())
                fill(clearRect)
                drawUnflippedImage(img, in: newRect)
            }
        case .text(let str, let font, _ /*let tmode*/):
            let attribStr = NSAttributedString(string: str, attributes: [.font: font.toUiFont()])
            UIGraphicsPushContext(self)
            let pt = operation.origin.cgPoint()
            // OPL text drawing coords are for the bottom left of the text, not the top left, so we have to adjust
            // the coords we pass to UIKit
            let sz = attribStr.size()
            attribStr.draw(at: CGPoint(x: pt.x, y: pt.y - sz.height))
            UIGraphicsPopContext()
        }
    }

    func drawUnflippedImage(_ img: CGImage, in rect: CGRect) {
        // Need to make sure the image draws the right way up so we have to flip back to normal coords, and
        // apply the y coordinate conversion ourselves
        self.concatenate(self.coordinateFlipTransform.inverted())
        let unflippedRect = CGRect(x: rect.minX, y: CGFloat(self.height) - rect.minY - rect.height, width: rect.width, height: rect.height)
        self.draw(img, in: unflippedRect)
        // And restore for other ops
        self.concatenate(self.coordinateFlipTransform)
    }
}
