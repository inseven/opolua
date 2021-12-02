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

    func canvasView(_ canvasView: CanvasView, touchesBegan touches: Set<UITouch>, with event: UIEvent?)
    func canvasView(_ canvasView: CanvasView, touchesMoved touches: Set<UITouch>, with event: UIEvent?)
    func canvasView(_ canvasView: CanvasView, touchesEnded touches: Set<UITouch>, with event: UIEvent?)

}

class CanvasView : UIView, Drawable {

    var canvas: Canvas
    weak var delegate: CanvasViewDelegate?

    var image: CGImage? {
        return canvas.image
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(size: CGSize) {
        canvas = Canvas(size: size)
        super.init(frame: .zero)
        clipsToBounds = true
    }

    func draw(_ operations: [Graphics.Operation]) {
        canvas.draw(operations)
        setNeedsDisplay()
    }

    override var intrinsicContentSize: CGSize {
        return canvas.size
    }

    override func draw(_ rect: CGRect) {
        guard let image = canvas.image,
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
        delegate?.canvasView(self, touchesBegan: touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.canvasView(self, touchesMoved: touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.canvasView(self, touchesEnded: touches, with: event)
    }

}
