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

extension CGContext {

    func gXBorder(type: Int, frame: CGRect) {
        let filename = String(format: "%05X", type)

        guard let url = Bundle.main.url(forResource: filename, withExtension: "png", subdirectory: "Borders") else {
            print("No resource found for border type \(type) (\(filename).png)")
            return
        }
        let image = CommonImage(contentsOfFile: url.path)!
        // I don't really understand why we have to limit the inset size so agressively here, but
        // limiting to half the frame size is not sufficient to avoid some weird artifacts
        let inset = min(min(frame.width, frame.height) / 3, 10)
#if canImport(UIKit)
        let button = image.resizableImage(withCapInsets: .init(top: inset, left: inset, bottom: inset, right: inset), resizingMode: .stretch)
#else
        let button = image
        button.capInsets = NSEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        button.resizingMode = .stretch
#endif
        let view = CommonImageView(image: button)

#if canImport(UIKit)
        let layer = view.layer
#else
        view.wantsLayer = true
        let layer = view.layer!
#endif
        saveGState()
        self.translateBy(x: frame.origin.x, y: frame.origin.y)
        view.frame = CGRect(origin: .zero, size: frame.size)
        layer.render(in: self)
        restoreGState()
    }

}
