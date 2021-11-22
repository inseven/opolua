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

import CoreGraphics

extension Graphics.Operation {

    var origin: CGPoint {
        return CGPoint(x: x, y: y)
    }

}

extension CGContext {

    func draw(_ operation: Graphics.Operation) {
        // TODO: Scale for the iOS screensize
        // TODO: Set the stroke and fill colours
        switch operation.type {
        case .cls:
            setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
            fill(CGRect(origin: .zero, size: CGSize(width: width, height: height)))
        case .circle(let radius, let fill):
            let path = CGMutablePath()
            path.addArc(center: operation.origin,
                        radius: CGFloat(radius),
                        startAngle: 0,
                        endAngle: Double.pi * 2,
                        clockwise: true)
            setLineWidth(1.0)
            addPath(path)
            strokePath()
            if fill {
                fillPath()
            }
            break
        case .line(let x, let y):
            let path = CGMutablePath()
            path.move(to: operation.origin)
            path.addLine(to: CGPoint(x: x, y: y))
            addPath(path)
            strokePath()
            break
        }
    }

}
