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

    var size: Graphics.Size {
        return canvas.size
    }

    private var canvas: Canvas
    private var greyPlane: Canvas?
    private var image: CGImage?
    private var invertedMask: CGImage?
    var clockView: ClockView?
    weak var delegate: CanvasViewDelegate?
    private var sprites: [Int: CanvasSprite] = [:]

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

    func draw(_ operation: Graphics.DrawCommand, provider: DrawableImageProvider) -> Graphics.Error? {
        defer {
            self.image = nil
            self.invertedMask = nil
            setNeedsDisplay()
        }
        if operation.greyMode.drawGreyPlane {
            precondition(self.mode == .gray4, "Bad window mode for a grey plane operation!")
            if self.greyPlane == nil {
                // The grey plane canvas's mode doesn't really matter here so long as it translates to 8bpp greyscale
                self.greyPlane = Canvas(id: self.canvas.id, size: self.canvas.size, mode: .gray2)
            }
            if let err = self.greyPlane?.draw(operation, provider: provider) {
                return err
            }
        }
        if operation.greyMode.drawNormalPlane {
            if let err = canvas.draw(operation, provider: provider) {
                return err
            }
        }
        return nil
    }

    func setSprite(_ sprite: CanvasSprite?, for id: Int) {
        if let sprite = sprite {
            self.sprites[id] = sprite
        } else {
            self.sprites.removeValue(forKey: id)
        }
        // print(self.sprites)
        self.image = nil
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
            self.image = nil
            setNeedsDisplay()
        }
        return true
    }

    func getImage() -> CGImage? {
        if let image = self.image {
            return image
        }
        guard let canvasImage = canvas.getImage() else {
            return nil
        }
        // Check to see if we have any active sprites; if not, then we can stop here.
        if sprites.isEmpty && self.greyPlane == nil {
            return canvasImage
        }

        // If our window contains any sprites or a grey plane, we composite these into a secondary context.
        guard let context = CGContext(data: nil,
                                      width: canvasImage.width,
                                      height: canvasImage.height,
                                      bitsPerComponent: canvasImage.bitsPerComponent,
                                      bytesPerRow: canvasImage.bytesPerRow,
                                      space: canvasImage.colorSpace!,
                                      bitmapInfo: canvasImage.bitmapInfo.rawValue) else {
            return nil
        }
        let rect = CGRect(origin: .zero, size: canvasImage.cgSize)
        context.draw(canvasImage, in: rect)

        if let greyPlaneImg = self.greyPlane?.getImage() {
            context.saveGState()
            // First, clip so we only draw the grey plane into white (ie unset) pixels in canvasImage
            context.clip(to: rect, mask: canvasImage.inverted()!.masking(componentRange: 1, to: 255)!)
            // Now clip again to only the drawn parts of the grey plane
            context.clip(to: rect, mask: greyPlaneImg.inverted()!.masking(componentRange: 0, to: 0)!)
            // At which point the clip rect is the union of what was white in
            // the main canvas, and set in the grey plane, so we can just fill
            // that.
            context.setFillColor(CGColor(gray: CGFloat(0xAA)/256, alpha: 1.0))
            context.fill(rect)
            context.restoreGState()
        }

        for sprite in self.sprites.values {
            guard let frame = sprite.currentFrame else {
                continue
            }
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
        self.image = image
        return image
    }

    func getInvertedMask() -> CGImage? {
        if self.invertedMask == nil {
            self.invertedMask = getImage()?.inverted()?.masking(componentRange: 0, to: 0)
        }
        return self.invertedMask
    }

    func getData() -> UnsafeBufferPointer<UInt32> {
        return getImage()!.getPixelData()
    }

    override var intrinsicContentSize: CGSize {
        return canvas.size.cgSize()
    }

    override func draw(_ rect: CGRect) {
        guard let image = getImage(),
              let context = UIGraphicsGetCurrentContext()
        else {
            return
        }
        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(canvas.size.height))
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(image, in: CGRect(origin: .zero, size: canvas.size.cgSize()))
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

    func resize(to newSize: Graphics.Size) {
        let oldCanvas = self.canvas
        self.canvas = Canvas(id: id, size: newSize, mode: oldCanvas.mode)
        if let img = oldCanvas.getImage() {
            self.canvas.draw(image: img)
        }
        self.bounds = CGRect(origin: .zero, size: newSize.cgSize())
    }

}
