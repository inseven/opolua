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

import CoreGraphics

extension Graphics.Color {
    func cgColor() -> CGColor {
        return CGColor(red: CGFloat(self.r) / 256, green: CGFloat(self.g) / 256, blue: CGFloat(self.b) / 256, alpha: 1)
    }
}

extension Graphics.Size {
    func cgSize() -> CGSize {
        return CGSize(width: self.width, height: self.height)
    }
}

extension Graphics.Point {
    func cgPoint() -> CGPoint {
        return CGPoint(x: self.x, y: self.y)
    }
}

extension Graphics.Rect {
    func cgRect() -> CGRect {
        return CGRect(x: self.origin.x, y: self.origin.y, width: self.width, height: self.height)
    }

    // Returns nil if there is no overlap between the rects
    public func intersection(_ rect: Graphics.Rect) -> Graphics.Rect? {
        let result = self.cgRect().intersection(rect.cgRect())
        if result.isNull {
            return nil
        }
        return Graphics.Rect(x: Int(result.minX), y: Int(result.minY),
            width: Int(result.width), height: Int(result.height))
    }

}
