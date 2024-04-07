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

import Foundation
import CoreGraphics
import UIKit

extension CGContext {

    var coordinateFlipTransform: CGAffineTransform {
        return CGAffineTransform(scaleX: 1.0, y: -1.0).translatedBy(x: 0.0, y: -CGFloat(self.height))
    }

    func draw(_ operation: Graphics.DrawCommand, provider: DrawableImageProvider) {
        let col: CGColor
        if operation.mode == .clear {
            col = operation.bgcolor.cgColor()
        } else {
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
            drawPixelLine(from: operation.origin.cgPoint(), to: endPoint.cgPoint())
        case .box(let size):
            let rect = CGRect(origin: operation.origin.cgPoint().move(x: 0.5, y: 0.5),
                              size: size.cgSize().adding(dx: -1, dy: -1))
            addPath(CGPath(rect: rect, transform: nil))
            strokePath()
        case .bitblt(let pxInfo):
            let cgImg = CGImage.from(bitmap: pxInfo)
            drawUnflippedImage(cgImg, in: CGRect(origin: operation.origin.cgPoint(), size: pxInfo.size.cgSize()))
        case .copy(let src, let mask):
            guard let srcImage = provider.getImageFor(drawable: src.drawableId) else {
                print("Failed to get image for .copy operation!")
                return
            }

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

            let maskImg: CGImage?
            if let mask = mask {
                maskImg = provider.getImageFor(drawable: mask.drawableId)
            } else {
                maskImg = nil
            }

            if let img = srcImage.cropping(to: rect) {
                let imgRect = CGRect(origin: CGPoint(x: destX, y: destY), size: rect.size)
                drawUnflippedImage(img, in: imgRect, mode: operation.mode, mask: maskImg)
            }
        case .pattern(let info):
            let srcImage: CGImage?
            if info.drawableId.value == -1 {
                srcImage = UIImage.ditherPattern().cgImage
            } else {
                srcImage = provider.getImageFor(drawable: info.drawableId)
            }
            guard let srcImage = srcImage else {
                print("Failed to get image for .pattern operation id=\(info.drawableId.value))!")
                return
            }
            drawUnflippedImage(srcImage, in: info.rect.cgRect(), mode: operation.mode, tile: true)
        case .scroll(let dx, let dy, let rect):
            // Make sure we don't inadvertently stretch or try to scroll beyond image limits
            let contextRect = CGRect(x: 0, y: 0, width: self.width, height: self.height)
            let origRect = rect.cgRect().intersection(contextRect)
            if let img = makeImage()?.cropping(to: origRect) {
                let newRect = CGRect(x: origRect.minX + CGFloat(dx), y: origRect.minY + CGFloat(dy), width: origRect.width, height: origRect.height).standardized
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
        case .text(let str, let fontInfo, let xstyle):
            let pt = operation.origin.cgPoint()
            var bgcolor = operation.bgcolor.cgColor()
            var fgcolor = operation.color.cgColor()
            var inverse = fontInfo.flags.contains(.inverse)
            let xstyleInverse = xstyle == .inverse || xstyle == .inverseNoCorner || xstyle == .thinInverse || xstyle == .thinInverseNoCorner
            if  xstyleInverse {
                // Yes, gSTYLE inverse and gXPRINT inverse stack
                inverse = !inverse
            }
            if xstyle == .thinUnderlined {
                // This smells like a bug, but gSTYLE inverse doesn't apply on
                // thinUnderlined, despite the fact that it does with underlined
                // and normal...
                inverse = false
            }
            if inverse {
                swap(&bgcolor, &fgcolor)
            }
            self.setStrokeColor(fgcolor)
            self.setFillColor(fgcolor)
            if let font = fontInfo.toBitmapFont() {
                let bold = fontInfo.flags.contains(.bold)
                let renderer = BitmapFontCache.shared.getRenderer(font: font, embolden: bold)
                var x = operation.origin.x
                let y = operation.origin.y
                let (textWidth, textHeight) = renderer.getTextSize(str)
                if operation.mode == .replace || inverse || xstyle != nil {
                    // gXPRINT always draws background, despite what the docs
                    // say about how it interacts with gTMODE. Likewise gSTYLE
                    // inverse always behaves like gTMODE is replace.
                    var bgRect = CGRect(x: x, y: y, width: textWidth, height: textHeight)
                    // From the point of view of the background size, underlined counts as "thin"
                    // even though that's really not obvious
                    let thin = xstyle == .thinInverse || xstyle == .thinInverseNoCorner || xstyle == .underlined || xstyle == .thinUnderlined
                    if xstyle != nil && !thin {
                        // Non-thin gXPRINT styles draw an extra pixel all round
                        bgRect = bgRect.insetBy(dx: -1, dy: -1)
                    }
                    self.saveGState()
                    self.setFillColor(bgcolor)
                    if xstyle == .normal || xstyle == .inverseNoCorner || xstyle == .thinInverseNoCorner {
                        self.clipToCornerlessBox(bgRect)
                    }
                    self.fill(bgRect)
                    restoreGState()
                }
                for ch in str {
                    if let img = renderer.getImageForChar(ch) {
                        let rect = CGRect(x: x, y: y, width: img.width, height: img.height)
                        self.saveGState()
                        self.concatenate(self.coordinateFlipTransform.inverted())
                        let unflippedRect = CGRect(x: rect.minX, y: CGFloat(self.height) - rect.minY - rect.height, width: rect.width, height: rect.height)
                        self.clip(to: unflippedRect, mask: img)
                        self.fill(unflippedRect)
                        self.restoreGState()
                        x = x + img.width
                    }
                }

                if xstyle == nil {
                    // gPRINT doesn't draw underlines in trailing space, but gXPRINT does (!)
                    var s = str
                    var numSpace = 0
                    var ch = s.popLast()
                    while ch == " " {
                        numSpace = numSpace + 1
                        ch = s.popLast()
                    }
                    x = x - numSpace * renderer.getTextSize(" ").0
                }

                if x <= operation.origin.x {
                    // There's nothing to underline (either text was empty or all spaces)
                    return
                }

                if fontInfo.flags.contains(.underlined) {
                    let lineStart = CGPoint(x: operation.origin.x, y: y + font.ascent + 1)
                    let lineEnd = CGPoint(x: CGFloat(x), y: lineStart.y)
                    drawPixelLine(from: lineStart, to: lineEnd)
                }

                if xstyle == .underlined {
                    // Yes this stacks with fontInfo underlined, and is drawn in a slightly different y offset
                    let lineStart = CGPoint(x: operation.origin.x, y: y + font.charh)
                    let lineEnd = CGPoint(x: CGFloat(x), y: lineStart.y)
                    drawPixelLine(from: lineStart, to: lineEnd)
                } else if xstyle == .thinUnderlined {
                    let lineStart = CGPoint(x: operation.origin.x, y: y + font.charh - 1)
                    let lineEnd = CGPoint(x: CGFloat(x), y: lineStart.y)
                    drawPixelLine(from: lineStart, to: lineEnd)
                }
            } else {
                let uifont = fontInfo.toUiFont()!
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
        case .invert(_ /*let size*/):
            fatalError("Shouldn't reach here") // Handled by Canvas
            /*
            let rect = Graphics.Rect(origin: operation.origin, size: size).cgRect()
            let flippedRect = rect.flipped(forHeight: CGFloat(self.height))
            let img = CIImage(cgImage: makeImage()!).cropped(to: flippedRect).applyingFilter("CIColorInvert")
            let cgImg = CIContext().createCGImage(img, from: img.extent)!
            self.saveGState()
            self.clipToCornerlessBox(rect)
            drawUnflippedImage(cgImg, in: rect)
            self.restoreGState()
            */
        }
    }

    func draw(image: CGImage) {
        let imgRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        drawUnflippedImage(image, in: imgRect)
    }

    private func drawUnflippedImage(_ img: CGImage, in rect: CGRect, mode: Graphics.Mode = .replace, mask: CGImage? = nil, tile: Bool = false) {
        // Need to make sure the image draws the right way up so we have to flip back to normal coords, and
        // apply the y coordinate conversion ourselves
        saveGState()
        defer {
            restoreGState()
        }
        self.concatenate(self.coordinateFlipTransform.inverted())
        let unflippedRect = rect.flipped(forHeight: CGFloat(self.height))
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
            self.clip(to: unflippedRect, mask: img.inverted()!.masking(componentRange: 0, to: 0)!)
            fill(unflippedRect)
            return
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

    private func drawPixelLine(from: CGPoint, to: CGPoint) {
        beginPath()
        var lineStart = from
        var lineEnd = to
        if lineStart.y == lineEnd.y && lineStart.x != lineEnd.x {
            // This is suprising, but seems to be needed to get clean ends
            lineStart = lineStart.move(x: 0, y: 0.5)
            lineEnd = lineEnd.move(x: 0, y: 0.5)
        } else if lineStart.x < lineEnd.x {
            lineStart = lineStart.move(x: 0.5, y: 0.5)
            lineEnd = lineEnd.move(x: -0.5, y: 0.5)
        } else if lineStart.x > lineEnd.x {
            lineStart = lineStart.move(x: -0.5, y: 0.5)
            lineEnd = lineEnd.move(x: 0.5, y: 0.5)
        } else {
            // Vertical line
            lineStart = lineStart.move(x: 0.5, y: 0.5)
            lineEnd = lineEnd.move(x: 0.5, y: 0.5)
        }
        move(to: lineStart)
        addLine(to: lineEnd)
        strokePath()
    }

    private func clipToCornerlessBox(_ rect: CGRect) {
        self.beginPath()
        self.addLines(between: [
            CGPoint(x: rect.minX + 1, y: rect.minY),
            CGPoint(x: rect.maxX - 1, y: rect.minY),
            CGPoint(x: rect.maxX - 1, y: rect.minY + 1),
            CGPoint(x: rect.maxX, y: rect.minY + 1),
            CGPoint(x: rect.maxX, y: rect.maxY - 1),
            CGPoint(x: rect.maxX - 1, y: rect.maxY - 1),
            CGPoint(x: rect.maxX - 1, y: rect.maxY),
            CGPoint(x: rect.minX + 1, y: rect.maxY),
            CGPoint(x: rect.minX + 1, y: rect.maxY - 1),
            CGPoint(x: rect.minX, y: rect.maxY - 1),
            CGPoint(x: rect.minX, y: rect.minY + 1),
            CGPoint(x: rect.minX + 1, y: rect.minY + 1),
            CGPoint(x: rect.minX + 1, y: rect.minY)
        ])
        self.clip()
    }
}
