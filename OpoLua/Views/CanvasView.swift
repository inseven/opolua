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

import UIKit

protocol CanvasViewDelegate: AnyObject {

    func canvasView(_ canvasView: CanvasView, touchBegan touch: UITouch, with event: UIEvent)
    func canvasView(_ canvasView: CanvasView, touchMoved touch: UITouch, with event: UIEvent)
    func canvasView(_ canvasView: CanvasView, touchEnded touch: UITouch, with event: UIEvent)

}

class CanvasView : UIView, Drawable {

    var id: Graphics.DrawableId {
        return canvas.id
    }

    var mode: Graphics.Bitmap.Mode {
        return canvas.mode
    }

    var canvas: Canvas
    var clockView: ClockView?
    weak var delegate: CanvasViewDelegate?
    var sprites: [Int: CanvasSprite] = [:]

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(canvas: Canvas, shadowSize: Int = 0) {
        self.canvas = canvas
        super.init(frame: .zero)
        clipsToBounds = false
        isMultipleTouchEnabled = false
        if shadowSize > 0 {
            self.layer.shadowRadius = 0
            self.layer.shadowOffset = CGSize(width: shadowSize, height: shadowSize)
            self.layer.shadowOpacity = 0.3
        }
    }

    func draw(_ operation: Graphics.DrawCommand) {
        canvas.draw(operation)
        setNeedsDisplay()
    }

    func setSprite(_ sprite: CanvasSprite?, for id: Int) {
        if let sprite = sprite {
            self.sprites[id] = sprite
        } else {
            self.sprites.removeValue(forKey: id)
        }
        // print(self.sprites)
        // self.image = nil
        setNeedsDisplay()
    }

    // Returns true if we still have any sprites being animated
    func updateSprites(elapsedTime: TimeInterval) -> Bool {
        if sprites.isEmpty {
            return false
        }
        var anythingChanged = false
        for sprite in self.sprites.values {
            if sprite.update(elapsedTime: elapsedTime) {
                anythingChanged = true
            }
        }
        if anythingChanged {
            // self.image = nil
            setNeedsDisplay()
        }
        return true
    }

    func getImage() -> CGImage? {
        guard let canvasImage = canvas.getImage() else {
            return nil
        }
        // Check to see if we have any active sprites; if not, then we can stop here.
        if sprites.isEmpty {
            return canvasImage
        }

        // If our window contains any sprites, we composite these into a secondary context.
        guard let context = CGContext(data: nil,
                                      width: canvasImage.width,
                                      height: canvasImage.height,
                                      bitsPerComponent: canvasImage.bitsPerComponent,
                                      bytesPerRow: canvasImage.bytesPerRow,
                                      space: canvasImage.colorSpace!,
                                      bitmapInfo: canvasImage.bitmapInfo.rawValue) else {
            return nil
        }
        context.draw(canvasImage, in: CGRect(origin: .zero, size: canvasImage.cgSize))
        for sprite in self.sprites.values {
            let frame = sprite.currentFrame
            guard let image = frame.bitmap.getImage(),
                  let mask = frame.mask.getImage()
            else {
                continue
            }
            let maskedImage: CGImage
            if frame.invertMask {
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

            let origin = self.canvas.invertCoordinates(point: sprite.origin + frame.offset)
            let adjustedOrigin = origin - Graphics.Point(x: 0, y: image.size.height)
            let destRect = Graphics.Rect(origin: adjustedOrigin, size: image.size)
            context.draw(maskedImage, in: destRect.cgRect())
        }
        let image = context.makeImage()
        // should we try to cache the en-sprite-ified image?
        return image

    }

    override var intrinsicContentSize: CGSize {
        return canvas.size
    }

    override func draw(_ rect: CGRect) {
        guard let image = getImage(),
              let context = UIGraphicsGetCurrentContext()
        else {
            return
        }
        context.interpolationQuality = .none
        context.translateBy(x: 0, y: canvas.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(image, in: CGRect(origin: .zero, size: canvas.size))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let event = event,
              let touch = touches.first else {
            return
        }

        delegate?.canvasView(self, touchBegan: touch, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let event = event,
              let touch = touches.first else {
            return
        }
        delegate?.canvasView(self, touchMoved: touch, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let event = event,
              let touch = touches.first else {
            return
        }
        delegate?.canvasView(self, touchEnded: touch, with: event)
    }

    func resize(to newSize: CGSize) {
        let oldCanvas = self.canvas
        self.canvas = Canvas(id: id, size: newSize, mode: .color256)
        if let img = oldCanvas.getImage() {
            let dummyId = Graphics.DrawableId(value: 0)
            let src = Graphics.CopySource(drawableId: dummyId, rect: Graphics.Rect(x: 0, y: 0, width: img.width, height: img.height), extra: img)
            let dontCare = Graphics.Color(r: 0, g: 0, b: 0)
            let zero = Graphics.Point(x: 0, y: 0)
            self.canvas.draw(Graphics.DrawCommand(drawableId: dummyId, type: .copy(src, nil), mode: .set, origin: zero, color: dontCare, bgcolor: dontCare, penWidth: 1))
        }
        self.bounds = CGRect(origin: .zero, size: newSize)
    }

}
