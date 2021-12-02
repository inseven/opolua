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

class CanvasView : UIView, Drawable {

    var canvas: Canvas
    var imageView: UIImageView
    var image: CGImage? { // required by Drawable
        return imageView.image?.cgImage
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(size: CGSize) {
        canvas = Canvas(size: size)
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        super.init(frame: .zero)
        addSubview(imageView)
        imageView.image = .emptyImage(with: size)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = self.bounds
    }

    func draw(_ operations: [Graphics.Operation]) {
        canvas.draw(operations)
        if let img = canvas.image {
            self.imageView.image = UIImage(cgImage: img)
        }
    }

}
