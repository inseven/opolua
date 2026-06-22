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

#if canImport(UIKit)
import UIKit
#endif

import OpoLuaCore
import OplCore

class ClockView: ViewBase {
    var clockInfo: Graphics.ClockInfo {
        didSet {
            clockInfoUpdated()
        }
    }

    private func clockInfoUpdated() {
        let metrics = oplGetClockMetrics(clockInfo.type)
        if let imgName = metrics.name {
            analogClockImage = CommonImage(resource: .init(name: "clocks/" + String(cString: imgName) + ".png" , bundle: .main))
        } else {
            analogClockImage = nil
        }
        if let img = analogClockImage?.cgImage {
            size = img.size
        }

        if metrics.dateFont != 0 {
            dateFont = BitmapFontInfo(uid: metrics.dateFont)
        } else {
            dateFont = nil
        }

        if metrics.timeFont != 0 {
            timeFont = BitmapFontInfo(uid: metrics.timeFont)
        } else {
            timeFont = nil
        }
        hourHandLen = Double(metrics.hourHandLen)
        minuteHandLen = Double(metrics.minuteHandLen)

        switch clockInfo.type {
        case .invalidClock:
            break
        case .digitalSmall:
            var w = timeFont!.textWidth("10:00")
            if clockInfo.showSeconds {
                w += timeFont!.textWidth(":00")
            }
            size = .init(width: w, height: timeFont!.charh)
        case .analogSmall:
            if clockInfo.showDate {
                size.height += 1 + dateFont!.charh
            }
        case .digitalMedium:
            // clockInfo.showSeconds = false // This clock never shows seconds
            let w = timeFont!.textWidth("Mon 30")
            size = .init(width: w, height: timeFont!.charh * 2)
            if clockInfo.showDate {
                size.height += 1 + dateFont!.charh
            }
        case .analogMediumBlack:
            if clockInfo.showDate {
                size.height += 4 + dateFont!.charh
            }
        case .analogMediumS3a:
            if clockInfo.showDate {
                size.height += 1 + dateFont!.charh
            }
        case .analogMediumS5:
            break
        case .analogMediumColor:
            break
        case .analogLargeS3a:
            break
        case .analogLargeS5:
            break
        case .analogLargeColor:
            break
        case .digitalFont:
            // mInfo.showSeconds = false; // This clock never shows seconds
            size = .init(width: 61, height: 61) // Same as analogMediumS5
        case .digitalFontShadowed:
            // mInfo.showSeconds = false; // This clock never shows seconds
            size = .init(width: 51, height: 51) // Same as analogMediumS5
        }

        self.frame = CGRect(origin: clockInfo.position.cgPoint(), size: size.cgSize())
        setNeedsDisplay()
    }
    
    private var analogClockImage: CommonImage?
    private var size: Graphics.Size
    private var timeFont: BitmapFontInfo?
    private var dateFont: BitmapFontInfo?
    private var hourHandLen: Double
    private var minuteHandLen: Double

    init(clockInfo: Graphics.ClockInfo) {
        self.analogClockImage = nil
        self.size = Graphics.Size(width: 0, height: 0)
        self.hourHandLen = 0
        self.minuteHandLen = 0
        self.clockInfo = clockInfo
        super.init(frame: CGRect(origin: clockInfo.position.cgPoint(), size: self.size.cgSize()))
#if canImport(UIKit)
        self.isOpaque = false
#endif
        clockInfoUpdated()
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
        context.setFillColor(UIColor.black.cgColor)

        let t = Date(timeIntervalSinceNow: TimeInterval(clockInfo.offset))
        let components = Calendar.current.dateComponents([.hour, .minute], from: t)
        guard let hours = components.hour, let minutes = components.minute else {
            print("Date fail!")
            return
        }

        let displayHours = (hours == 12 ? 12 : hours % 12)
        let timeStr = String(format: "%d:%02d", displayHours, minutes)
        var leadingSpace = 0
        if displayHours < 10, let timeFont {
            leadingSpace = timeFont.textWidth("1")
        }
        let df = DateFormatter()
        df.dateFormat = "EEE d"
        let dateStr = df.string(from: t)

        let minFrac = Double(minutes) / 60
        let hAngle = Double.pi - 2 * Double.pi * ((Double(hours % 12) + minFrac) / 12)
        let mAngle = Double.pi - 2 * Double.pi * (minFrac)

        if let cgImage = analogClockImage?.cgImage {
            context.saveGState()
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: 0, y: -self.bounds.height);
            context.draw(cgImage, in: CGRect(x: 0, y: size.height - cgImage.height, width: cgImage.width, height: cgImage.height))
            context.restoreGState()
        }

        switch clockInfo.type {
        case .invalidClock:
            break
        case .digitalSmall:
            drawText(timeStr, context: context, font: timeFont!, x: leadingSpace, y: 0)
        case .analogSmall:
            context.setLineWidth(1)
            drawHands(context: context, hAngle: hAngle, mAngle: mAngle)
            if clockInfo.showDate {
                drawCenteredText(dateStr, context: context, font: dateFont!, y: size.height - dateFont!.charh)
            }
        case .digitalMedium:
            drawText(timeStr, context: context, font: timeFont!, x: leadingSpace, y: 0, scale: 2)
            if clockInfo.showDate {
                drawCenteredText(dateStr, context: context, font: dateFont!, y: size.height - dateFont!.charh)
            }
        case .analogMediumBlack:
            context.setLineWidth(2)
            drawHands(context: context, hAngle: hAngle, mAngle: mAngle)
            if clockInfo.showDate {
                drawCenteredText(dateStr, context: context, font: dateFont!, y: size.height - dateFont!.charh)
            }
        case .analogMediumS3a:
            context.setLineWidth(2)
            context.setFillColor(UIColor.white.cgColor)
            drawHands(context: context, hAngle: hAngle, mAngle: mAngle, shadow: UIColor.black.cgColor)
            if clockInfo.showDate {
                drawCenteredText(dateStr, context: context, font: dateFont!, y: size.height - dateFont!.charh)
            }
        case .analogMediumS5, .analogMediumColor:
            context.setLineWidth(2)
            drawHands(context: context, hAngle: hAngle, mAngle: mAngle)
        case .digitalFont:
            drawCenteredText(timeStr, context: context, font:timeFont!, y: 4)
            drawCenteredText(dateStr, context: context, font:dateFont!, y: 45)
        case .digitalFontShadowed:
            let textw = timeFont!.textWidth(timeStr) + 2
            let x = (Int(size.width) - textw) / 2
            let y = 8
            context.setFillColor(Graphics.Color.gray.cgColor())
            drawText(timeStr, context: context, font: timeFont!, x: x, y: y)
        case .analogLargeS3a:
            context.setLineWidth(2)
            context.setFillColor(UIColor.white.cgColor)
            drawHands(context: context, hAngle: hAngle, mAngle: mAngle, shadow: UIColor.black.cgColor)
        case .analogLargeS5, .analogLargeColor:
            context.setLineWidth(7)
            context.setLineCap(.round)
            drawHands(context: context, hAngle: hAngle, mAngle: mAngle)
        }
    }

    func drawCenteredText(_ text: String, context: CGContext, font: BitmapFontInfo, y: Int) {
        let w = font.textWidth(text)
        let x = (self.size.width - w) / 2
        drawText(text, context: context, font: font, x: x, y: y)
    }

    func drawText(_ text: String, context: CGContext, font: BitmapFontInfo, x: Int, y: Int, scale: CGFloat = 1) {
        context.saveGState()
        context.scaleBy(x: 1.0, y: -1.0 * scale)
        context.translateBy(x: 0, y: -self.bounds.height)
        let renderer = BitmapFontCache.shared.getRenderer(font: font)
        var x = x
        for ch in text {
            context.saveGState()
            if let img = renderer.getImageForChar(ch) {
                let rect = CGRect(x: x, y: size.height - font.charh - y, width: img.width, height: img.height)
                context.clip(to: rect, mask: img)
                context.fill(rect)
                x = x + img.width
            }
            context.restoreGState()
        }
        context.restoreGState()
    }

    func drawHands(context: CGContext, hAngle: Double, mAngle: Double, shadow: CGColor? = nil) {
        guard let clockImg = analogClockImage else {
            return
        }
        let centerPos = CGPoint(x: clockImg.size.width / 2, y: clockImg.size.height / 2)

        if let shadow {
            context.saveGState()
            context.setFillColor(shadow)
            let shadowCenter = CGPoint(x: centerPos.x + 1, y: centerPos.y + 1)
            context.move(to: shadowCenter)
            context.addLine(to: CGPoint(x: shadowCenter.x + sin(hAngle) * hourHandLen, y: shadowCenter.y + cos(hAngle) * hourHandLen))
            context.strokePath()
            context.move(to: shadowCenter)
            context.addLine(to: CGPoint(x: shadowCenter.x + sin(mAngle) * minuteHandLen, y: shadowCenter.y + cos(mAngle) * minuteHandLen))
            context.strokePath()
            context.restoreGState()
        }

        context.move(to: centerPos)
        context.addLine(to: CGPoint(x: centerPos.x + sin(hAngle) * hourHandLen, y: centerPos.y + cos(hAngle) * hourHandLen))
        context.strokePath()

        context.move(to: centerPos)
        context.addLine(to: CGPoint(x: centerPos.x + sin(mAngle) * minuteHandLen, y: centerPos.y + cos(mAngle) * minuteHandLen))
        context.strokePath()
    }

#endif

    func clockChanged() {
        self.frame = CGRect(origin: clockInfo.position.cgPoint(), size: self.size.cgSize())
        self.setNeedsDisplay()
    }

}
