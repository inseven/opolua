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

import UIKit

protocol CanvasViewDelegate: AnyObject {

    func canvasView(_ canvasView: CanvasView, touchBegan touch: UITouch, with event: UIEvent)
    func canvasView(_ canvasView: CanvasView, touchMoved touch: UITouch, with event: UIEvent)
    func canvasView(_ canvasView: CanvasView, touchEnded touch: UITouch, with event: UIEvent)

}

class CanvasView : UIView, Drawable {

    var id: Int {
        return canvas.id
    }

    var canvas: Canvas
    weak var delegate: CanvasViewDelegate?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(id: Int, size: CGSize, shadowSize: Int = 0) {
        canvas = Canvas(id: id, size: size, color: true)
        super.init(frame: .zero)
        clipsToBounds = false
        isMultipleTouchEnabled = false
        if shadowSize > 0 {
            self.layer.shadowRadius = CGFloat(shadowSize)
            self.layer.shadowOpacity = 1
        }
    }

    func draw(_ operation: Graphics.DrawCommand) {
        canvas.draw(operation)
        setNeedsDisplay()
    }

    func getImage() -> CGImage? {
        return canvas.getImage()
    }

    override var intrinsicContentSize: CGSize {
        return canvas.size
    }

    override func draw(_ rect: CGRect) {
        guard let image = canvas.getImage(),
              let context = UIGraphicsGetCurrentContext()
        else {
            return
        }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: canvas.size))
        context.interpolationQuality = .none
        context.translateBy(x: 0, y: canvas.size.height);
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
        self.canvas = Canvas(id: id, size: newSize, color: true)
        if let img = oldCanvas.getImage() {
            let src = Graphics.CopySource(displayId: 0, rect: Graphics.Rect(x: 0, y: 0, width: img.width, height: img.height), extra: oldCanvas)
            let dontCare = Graphics.Color(r: 0, g: 0, b: 0)
            let zero = Graphics.Point(x: 0, y: 0)
            self.canvas.draw(Graphics.DrawCommand(displayId: 0, type: .copy(src, nil), mode: .set, origin: zero, color: dontCare, bgcolor: dontCare))
        }
        self.bounds = CGRect(origin: .zero, size: newSize)
    }

}
