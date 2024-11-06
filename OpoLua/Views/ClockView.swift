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

import Foundation

#if canImport(UIKit)

import UIKit

#endif

class ClockView: ViewBase {
    var clockInfo: Graphics.ClockInfo

    var systemClockDigital: Bool {
        didSet {
            setNeedsDisplay()
        }
    }
    
    private let analogClockImage: CommonImage

    init(analogClockImage: CommonImage, clockInfo: Graphics.ClockInfo, systemClockDigital: Bool) {
        self.clockInfo = clockInfo
        self.systemClockDigital = systemClockDigital
        self.analogClockImage = analogClockImage
        super.init(frame: CGRect(origin: clockInfo.position.cgPoint(), size: CGSize(width: 61.0, height: 61.0)))
#if canImport(UIKit)
        self.isOpaque = false
#endif
    }

#if !canImport(UIKit)
    override var isOpaque: Bool {
        return false
    }
#endif

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

#if canImport(UIKit) // TODO AppKit version
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0, y: -self.bounds.height);

        let now = Date()
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        guard let hours = components.hour, let minutes = components.minute else {
            print("Date fail!")
            return
        }

        let digital = clockInfo.mode == .digital || (clockInfo.mode == .systemSetting && systemClockDigital)
        if digital {
            let displayHours = (hours == 12 ? 12 : hours % 12)
            let text = String(format: "%d:%02d", displayHours, minutes) // TODO: we should honour the iOS 24hr format preference
            drawCenteredText(text, context: context, font: BitmapFontInfo.digit, y: 4)
            let df = DateFormatter()
            df.dateFormat = "EEE d"
            let day = df.string(from: now)
            drawCenteredText(day, context: context, font: BitmapFontInfo.arial15, y: 45)
        } else {
            if let cgImage = analogClockImage.cgImage {
                context.draw(cgImage, in: CGRect(origin: .zero, size: analogClockImage.size))
            }
            let centerPos = CGPoint(x: analogClockImage.size.width / 2, y: analogClockImage.size.height / 2)
            let minFrac = Double(minutes) / 60
            let hourHandLen = 18.0
            let minuteHandLen = 25.0
            let hAngle = 2 * Double.pi * ((Double(hours % 12) + minFrac) / 12)
            context.setLineWidth(2)
            context.move(to: centerPos)
            context.addLine(to: CGPoint(x: centerPos.x + sin(hAngle) * hourHandLen, y: centerPos.y + cos(hAngle) * hourHandLen))
            context.strokePath()
            let mAngle = 2 * Double.pi * (minFrac)
            context.move(to: centerPos)
            context.addLine(to: CGPoint(x: centerPos.x + sin(mAngle) * minuteHandLen, y: centerPos.y + cos(mAngle) * minuteHandLen))
            context.strokePath()
        }
    }

    func drawCenteredText(_ text: String, context: CGContext, font: BitmapFontInfo, y: CGFloat) {
        let renderer = BitmapFontCache.shared.getRenderer(font: font)
        let (w, h) = renderer.getTextSize(text)
        var x = (self.bounds.width - CGFloat(w)) / 2
        context.setFillColor(UIColor.black.cgColor)
        for ch in text {
            context.saveGState()
            if let img = renderer.getImageForChar(ch) {
                let rect = CGRect(x: x, y: self.bounds.height - CGFloat(h) - y, width: CGFloat(img.width), height: CGFloat(img.height))
                context.clip(to: rect, mask: img)
                context.fill(rect)
                x = x + CGFloat(img.width)
            }
            context.restoreGState()
        }
    }
#endif

    func clockChanged() {
        self.frame = CGRect(origin: clockInfo.position.cgPoint(), size: analogClockImage.size)
        self.setNeedsDisplay()
    }

}
