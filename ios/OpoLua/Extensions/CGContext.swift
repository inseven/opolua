// Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe
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

import OpoLuaCore

extension CGContext {

    var coordinateFlipTransform: CGAffineTransform {
        return CGAffineTransform(scaleX: 1.0, y: -1.0).translatedBy(x: 0.0, y: -CGFloat(self.height))
    }

    func draw(_ operation: Graphics.DrawCommand, buffer: UnsafeMutableBufferPointer<UInt32>, provider: DrawableImageProvider) -> Graphics.Error? {
        let col: CGColor
        let colVal: UInt32
        if operation.mode == .clear {
            col = operation.bgcolor.cgColor()
            colVal = operation.bgcolor.pixelValue
        } else {
            col = operation.color.cgColor()
            colVal = operation.color.pixelValue
        }

        let drawSinglePixel: (Int, Int) -> Void
        switch operation.mode {
        case .set, .clear, .replace:
            drawSinglePixel = { x, y in
                if x >= 0 && x < self.width && y >= 0 && y < self.height {
                    buffer[y * self.width + x] = colVal
                }
            }
        case .invert:
            let xorVal = ~colVal & ~Graphics.Color.alphaMask
            drawSinglePixel = { x, y in
                if x >= 0 && x < self.width && y >= 0 && y < self.height {
                    let pos = y * self.width + x
                    buffer[pos] = buffer[pos] ^ xorVal
                }
            }
        }
        let drawPixel: (Int, Int) -> Void
        // I'm not sure how to do invert with a pen width... for now, just don't.
        if operation.penWidth <= 1 || operation.mode == .invert {
            drawPixel = drawSinglePixel
        } else {
            let sub = operation.penWidth / 2
            let add = (operation.penWidth - 1) - sub
            drawPixel = { x, y in
                for yy in y - sub ... y + add {
                    for xx in x - sub ... x + add {
                        drawSinglePixel(xx, yy)
                    }
                }
            }
        }

        setStrokeColor(col)
        setFillColor(col)
        setLineWidth(CGFloat(operation.penWidth))
        switch operation.type {
        case .fill(let size):
            if operation.mode == .invert {
                for y in 0 ..< size.height {
                    for x in 0 ..< size.width {
                        drawSinglePixel(operation.origin.x + x, operation.origin.y + y)
                    }
                }
            } else {
                fill(CGRect(origin: operation.origin.cgPoint(), size: size.cgSize()))
            }
        case .invert(let size):
            for y in 0 ..< size.height {
                for x in 0 ..< size.width {
                    if (x == 0 || x == size.width - 1) && (y == 0 || y == size.height - 1) {
                        // gINVERT doesn't draw corner pixels
                    } else {
                        drawSinglePixel(operation.origin.x + x, operation.origin.y + y)
                    }
                }
            }
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
            drawLine(x0: operation.origin.x, y0: operation.origin.y, x1: endPoint.x, y1: endPoint.y, drawPixel: drawPixel)
        case .box(let size):
            let x = operation.origin.x
            let y = operation.origin.y
            let w = size.width - 1
            let h = size.height - 1
            drawLine(x0: x, y0: y, x1: x + w, y1: y, drawPixel: drawPixel) // top
            drawLine(x0: x + w, y0: y, x1: x + w, y1: y + h, drawPixel: drawPixel) // right
            drawLine(x0: x + w, y0: y + h, x1: x, y1: y + h, drawPixel: drawPixel) // bottom
            drawLine(x0: x, y0: y + h, x1: x, y1: y, drawPixel: drawPixel) // left
        case .bitblt(let pxInfo):
            precondition(operation.mode == .replace)
            let cgImg = CGImage.from(bitmap: pxInfo)
            drawUnflippedImage(cgImg, in: CGRect(origin: operation.origin.cgPoint(), size: pxInfo.size.cgSize()))
        case .copy(let src, let mask):
            precondition(mask == nil || operation.mode == .replace) // mask only supported with replace mode

            guard let srcDrawable = provider.getDrawable(src.drawableId) else {
                print("Failed to get image for .copy operation!")
                return .badDrawable
            }

            guard let (srcRect, dest) = adjustBounds(srcRect: src.rect, dest: operation.origin, srcSize: srcDrawable.size) else {
                return nil
            }

            if operation.mode == .clear || operation.mode == .invert {
                doClearInvertCopy(buffer: buffer, mode: operation.mode, srcDrawable: srcDrawable, srcRect: srcRect, dest: dest)
                return nil
            }

            let maskDrawable: Drawable?
            if let mask = mask {
                maskDrawable = provider.getDrawable(mask.drawableId)
            } else {
                maskDrawable = nil
            }

            // drawUnflippedImage code path only used for .set and .replace
            let srcCgRect = srcRect.cgRect()
            if let img = srcDrawable.getImage()?.cropping(to: srcCgRect) {
                let imgRect = CGRect(origin: dest.cgPoint(), size: srcCgRect.size)
                drawUnflippedImage(img, in: imgRect, mode: operation.mode, mask: maskDrawable)
            }
        case .mcopy(let src, let rects, let points):
            precondition(operation.mode == .clear || operation.mode == .invert, "Invalid mode for mcopy operation!")
            guard let srcDrawable = provider.getDrawable(src) else {
                print("Failed to get image for .mcopy operation!")
                return .badDrawable
            }
            for i in 0 ..< min(rects.count, points.count) {
                if let (src, dest) = adjustBounds(srcRect: rects[i], dest: points[i], srcSize: srcDrawable.size) {
                    doClearInvertCopy(buffer: buffer, mode: operation.mode, srcDrawable: srcDrawable, srcRect: src, dest: dest)
                }
            }
        case .pattern(let info):
            let srcImage: CGImage?
            if info.drawableId.value == -1 {
                srcImage = provider.getDitherImage()
            } else {
                srcImage = provider.getDrawable(info.drawableId)?.getImage()
            }
            guard let srcImage = srcImage else {
                print("Failed to get image for .pattern operation id=\(info.drawableId.value))!")
                return .badDrawable
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
        case .border(let rect, let type):
            gXBorder(type: type, frame: rect.cgRect())
        }
        return nil
    }

    private func adjustBounds(srcRect: Graphics.Rect, dest: Graphics.Point, srcSize: Graphics.Size) -> (Graphics.Rect, Graphics.Point)? {
        // Both source and dest are allowed to be beyond the drawable bounds - copying from out of bounds is a no-op,
        // and writing to a destination out of bounds is ignored, so adjust srcRect and dest to be only the portion
        // that is fully in bounds for both.
        let destRect = Graphics.Rect(origin: dest, size: srcRect.size)
        let destBounds = Graphics.Rect(x: 0, y: 0, width: self.width, height: self.height)
        guard let destClipped = destRect.intersection(destBounds) else {
            // If no part of the destination is within the bounds of the Canvas then this operation is a no-op
            return nil
        }

        // Reduce src to match destClipped
        let srcAdjustedX = srcRect.minX + (destClipped.minX - destRect.minX)
        let srcAdjustedY = srcRect.minY + (destClipped.minY - destRect.minY)
        let srcAdjustedMaxX = srcRect.maxX + (destClipped.maxX - destRect.maxX)
        let srcAdjustedMaxY = srcRect.maxY + (destClipped.maxY - destRect.maxY)

        let srcAdjusted = Graphics.Rect(x: srcAdjustedX, y: srcAdjustedY, width: srcAdjustedMaxX - srcAdjustedX, height: srcAdjustedMaxY - srcAdjustedY)
        guard let srcClipped = srcAdjusted.intersection(Graphics.Rect(origin: .zero, size: srcSize)) else {
            // Likewise a no-op
            return nil
        }

        let destX = destClipped.minX + (srcClipped.minX - srcAdjusted.minX)
        let destY = destClipped.minY + (srcClipped.minY - srcAdjusted.minY)
        return (srcClipped, Graphics.Point(x: destX, y: destY))
    }

    private func doClearInvertCopy(buffer: UnsafeMutableBufferPointer<UInt32>, mode: Graphics.Mode, srcDrawable: Drawable, srcRect: Graphics.Rect, dest: Graphics.Point) {
        if mode == .clear {
            // A bit more optimised than drawImageUnflipped()
            let rect = srcRect.cgRect()
            let mask = srcDrawable.getInvertedMask()!.cropping(to: rect)!
            let destRect = CGRect(origin: dest.cgPoint(), size: rect.size)
            saveGState()
            defer {
                restoreGState()
            }
            self.concatenate(self.coordinateFlipTransform.inverted())
            let unflippedRect = destRect.flipped(forHeight: CGFloat(self.height))
            self.clip(to: unflippedRect, mask: mask)
            self.fill(unflippedRect)
        } else if mode == .invert {
            let srcPtr = srcDrawable.getData()
            let w = srcDrawable.size.width
            for y in 0 ..< srcRect.height {
                for x in 0 ..< srcRect.width {
                    let srcPx = srcPtr[w * (srcRect.minY + y) + srcRect.minX + x]
                    // Mode invert still only operates on non-white source pixels
                    if srcPx != Graphics.Color.white.pixelValue {
                        let pos = (dest.y + y) * self.width + dest.x + x
                        buffer[pos] = buffer[pos] ^ ~srcPx
                    }
                }
            }
        }
    }

    func draw(image: CGImage) {
        let imgRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        drawUnflippedImage(image, in: imgRect)
    }

    private func drawUnflippedImage(_ img: CGImage, in rect: CGRect, mode: Graphics.Mode = .replace, mask: Drawable? = nil, tile: Bool = false) {
        // Need to make sure the image draws the right way up so we have to flip back to normal coords, and
        // apply the y coordinate conversion ourselves
        saveGState()
        defer {
            restoreGState()
        }
        self.concatenate(self.coordinateFlipTransform.inverted())
        let unflippedRect = rect.flipped(forHeight: CGFloat(self.height))
        if let maskImg = mask?.getImage() {
            // Annoyingly, clip() expects the mask to be the inverse of how epoc
            // expects it (ie 0xFF meaning opaque whereas epoc uses 0x00 for
            // opaque), so we have to invert it ourselves. Probably should do
            // something more efficient here...
            clip(to: unflippedRect, mask: maskImg.stripAlpha(grayscale: true).inverted()!)
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

    private func drawLine(x0: Int, y0: Int, x1: Int, y1: Int, drawPixel: @escaping (Int, Int) -> Void) {
        // drawPixel really shouldn't need to be declared escaping, because it isn't, but the compiler is being dumb.

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
                drawPixel(scan, inc)
            }
            dscan = dx
            dinc = dy
            inc = y0
            scanStart = x0
            scanEnd = x1
        } else {
            drawXY = {
                drawPixel(inc, scan)
            }
            dscan = dy
            dinc = dx
            inc = x0
            scanStart = y0
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
        drawPixel(x0, y0)
        // OPL does not draw the end pixel of a line
        // drawPixel(x1, y1)

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
