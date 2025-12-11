// Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe
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

class PixelView: UIView {

    var image: UIImage? {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            setNeedsLayout()
            setNeedsDisplay()
        }
    }

    init(image: UIImage? = nil) {
        super.init(frame: .zero)
        self.image = image
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let image = image?.cgImage,
              let context = UIGraphicsGetCurrentContext()
        else {
            return
        }
        context.interpolationQuality = .none
        context.translateBy(x: 0, y: frame.size.height);
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(image, in: CGRect(origin: .zero, size: frame.size))
    }

    override var frame: CGRect {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            setNeedsLayout()
            setNeedsDisplay()
        }
    }

    override var description: String {
        return String(format: "<OpoLua.PixelView: %p, frame = %@, layer = %@, image = %@>", self, NSCoder.string(for: frame), layer, image ?? "nil")
    }

    override var intrinsicContentSize: CGSize {
        return image?.size ?? .zero
    }

}
