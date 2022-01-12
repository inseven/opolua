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
        setLineWidth(CGFloat(operation.penWidth))
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
            path.addLine(to: endPoint.cgPoint().move(x: 0.5, y: 0.5))
            addPath(path)
            strokePath()
        case .box(let size):
            let rect = CGRect(origin: operation.origin.cgPoint().move(x: 0.5, y: 0.5),
                              size: size.cgSize().adding(dx: -1, dy: -1))
            addPath(CGPath(rect: rect, transform: nil))
            strokePath()
        case .bitblt(let pxInfo):
            let cgImg = CGImage.from(bitmap: pxInfo)
            drawUnflippedImage(cgImg, in: CGRect(origin: operation.origin.cgPoint(), size: pxInfo.size.cgSize()))
        case .copy(let src, let mask):
            guard let obj = src.extra else {
                print("Unexpected nil extra!")
                return
            }
            let srcImage = obj as! CGImage // CF types are weird...

            // Clip the rect to the source size to make sure we don't inadvertently stretch it
            let rect = src.rect.cgRect().intersection(CGRect(x: 0, y: 0, width: srcImage.width, height: srcImage.height))

            // OPL lets your src rect extend beyond the top and left of the
            // image, in which case we need to adjust the dest pos
            var destX = operation.origin.cgPoint().x
            var destY = operation.origin.cgPoint().y
            if src.rect.minX < 0 {
                destX = destX + CGFloat(-src.rect.minX)
            }
            if src.rect.minY < 0 {
                destY = destY + CGFloat(-src.rect.minY)
            }

            let maskImg = (mask?.extra as? Drawable)?.getImage()
            if let img = srcImage.cropping(to: rect) {
                let imgRect = CGRect(origin: CGPoint(x: destX, y: destY), size: rect.size)
                drawUnflippedImage(img, in: imgRect, mode: operation.mode, mask: maskImg)
            }
        case .pattern(let info):
            guard let obj = info.extra else {
                print("Unexpected nil extra!")
                return
            }
            let srcImage = obj as! CGImage // CF types are weird...
            drawUnflippedImage(srcImage, in: info.rect.cgRect(), mode: operation.mode, tile: true)
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
        case .text(let str, let font):
            let pt = operation.origin.cgPoint()
            if let font = font.toBitmapFont() {
                let renderer = BitmapFontCache.shared.getRenderer(font: font)
                var x = operation.origin.x
                var y = operation.origin.y
                for ch in str {
                    if ch == "\n" {
                        y = y + font.charh
                        x = operation.origin.x
                        continue
                    }
                    if let img = renderer.getImageForChar(ch) {
                        let rect = CGRect(x: x, y: y, width: img.width, height: img.height)
                        self.saveGState()
                        self.concatenate(self.coordinateFlipTransform.inverted())
                        let unflippedRect = CGRect(x: rect.minX, y: CGFloat(self.height) - rect.minY - rect.height, width: rect.width, height: rect.height)
                        if operation.mode == .replace {
                            self.setFillColor(operation.bgcolor.cgColor())
                            self.fill(unflippedRect)
                            self.setFillColor(operation.color.cgColor())
                        }
                        self.clip(to: unflippedRect, mask: img)
                        self.fill(unflippedRect)
                        self.restoreGState()
                        x = x + img.width
                    }
                }
            } else {
                let uifont = font.toUiFont()!
                UIGraphicsPushContext(self)
                let attribStr = NSAttributedString(string: str, attributes: [
                    .font: uifont,
                    .foregroundColor: UIColor(cgColor: col)
                ])
                attribStr.draw(at: CGPoint(x: pt.x, y: pt.y))
                UIGraphicsPopContext()
            }
        case .border(let rect, let type):
            gXBorder(type: type, frame: rect.cgRect())
        case .invert(let size):
            let rect = Graphics.Rect(origin: operation.origin, size: size).cgRect()
            let img = CIImage(cgImage: makeImage()!).cropped(to: rect).applyingFilter("CIColorInvert")
            let cgImg = CIContext().createCGImage(img, from: img.extent)!
            drawUnflippedImage(cgImg, in: rect) // TODO mask out the corner pixels
        }
    }

    func drawUnflippedImage(_ img: CGImage, in rect: CGRect, mode: Graphics.Mode = .replace, mask: CGImage? = nil, tile: Bool = false) {
        // Need to make sure the image draws the right way up so we have to flip back to normal coords, and
        // apply the y coordinate conversion ourselves
        saveGState()
        defer {
            restoreGState()
        }
        self.concatenate(self.coordinateFlipTransform.inverted())
        let unflippedRect = CGRect(x: rect.minX, y: CGFloat(self.height) - rect.minY - rect.height, width: rect.width, height: rect.height)
        if let mask = mask {
            // Annoyingly, clip() expects the mask to be the inverse of how epoc
            // expects it (ie 0xFF meaning opaque whereas epoc uses 0x00 for
            // opaque), so we have to invert it ourselves. Probably should do
            // something more efficient here...
            clip(to: unflippedRect, mask: mask.inverted()!)
        }

        var imgToDraw = img
        switch mode {
        case .set:
            // .set means only draw the non-white pixels which we can achieve by
            // setting a colour mask on the image set to min=255 max=255
            if let maskedImg = imgToDraw.masking(componentRange: 255, to: 255) {
                imgToDraw = maskedImg
            } else {
                print("Image masking operation failed!")
            }
        case .clear:
            print("TODO: drawUnflippedImage .clear")
        case .invert:
            print("TODO: drawUnflippedImage .invert")
        case .replace:
            break
        }
        if tile {
            clip(to: unflippedRect)
            let imgRect = CGRect(x: 0, y: 0, width: img.width, height: img.height)
            self.draw(imgToDraw, in: imgRect, byTiling: true)
        } else {
            self.draw(imgToDraw, in: unflippedRect)
        }
    }
}
