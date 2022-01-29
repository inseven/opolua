// Copyright (c) 2021-2022 Jason Morley, Tom Sutcliffe
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

import GameController
import UIKit

protocol WindowServerDelegate: CanvasViewDelegate {

    func windowServerClockIsDigital(_ windowServer: WindowServer) -> Bool

}

class WindowServer {

    static func textSize(string: String, fontInfo: Graphics.FontInfo) -> Graphics.TextMetrics {
        if let font = fontInfo.toBitmapFont() {
            let bold = fontInfo.flags.contains(.bold)
            let renderer = BitmapFontCache.shared.getRenderer(font: font, embolden: bold)
            let (w, h) = renderer.getTextSize(string)
            return Graphics.TextMetrics(size: Graphics.Size(width: w, height: h), ascent: font.ascent, descent: font.descent)
        } else {
            let font = fontInfo.toUiFont()! // One or other has to return non-nil
            let attribStr = NSAttributedString(string: string, attributes: [.font: font])
            let sz = attribStr.size()
            // This is not really the right definition for ascent but it seems to work for where epoc expects
            // the text to be, so...
            let ascent = Int(ceil(sz.height) + font.descender)
            let descent = Int(ceil(font.descender))
            return Graphics.TextMetrics(size: Graphics.Size(width: Int(ceil(sz.width)), height: Int(ceil(sz.height))),
                                        ascent: ascent, descent: descent)
        }
    }

    weak var delegate: WindowServerDelegate?

    private var device: Device
    private var screenSize: Graphics.Size
    private var drawableHandle = (1...).makeIterator()
    private var drawablesById: [Graphics.DrawableId: Drawable] = [:]
    private var windows: [Graphics.DrawableId: CanvasView] = [:] // convenience
    private var infoDrawableHandle: Graphics.DrawableId?
    private var infoWindowDismissTimer: Timer?
    private var busyDrawableHandle: Graphics.DrawableId?
    private var busyWindowShowTimer: Timer?
    private var spriteWindows: [Int: Graphics.DrawableId] = [:]
    private var spriteTimer: Timer?
    private var clockTimer: Timer?

    public var drawables: [Drawable] {
        return Array(drawablesById.values).sorted { $0.id.value < $1.id.value }
    }

    lazy var rootView: UIView = {
        let view = RootView(screenSize: screenSize.cgSize())
        let screenRect = Graphics.Rect(origin: .zero, size: screenSize)
        let id = createWindow(rect: screenRect, mode: .color256, shadowSize: 0)
        assert(id == .defaultWindow)
        let defaultWindow = self.windows[id]!
        view.addSubview(defaultWindow)
        defaultWindow.isHidden = false
        return view
    }()

    init(device: Device, screenSize: Graphics.Size) {
        self.device = device
        self.screenSize = screenSize
    }

    func drawable(for drawableId: Graphics.DrawableId) -> Drawable? {
        dispatchPrecondition(condition: .onQueue(.main))
        return drawablesById[drawableId]
    }

    func window(for drawableId: Graphics.DrawableId) -> CanvasView? {
        dispatchPrecondition(condition: .onQueue(.main))
        return windows[drawableId]
    }

    private func newCanvas(size: CGSize, mode: Graphics.Bitmap.Mode) -> Canvas {
        dispatchPrecondition(condition: .onQueue(.main))
        let id = Graphics.DrawableId(value: drawableHandle.next()!)
        let canvas = Canvas(windowServer: self, id: id, size: size, mode: mode)
        return canvas
    }

    /**
     N.B. Windows are hidden by default.
     */
    func createWindow(rect: Graphics.Rect, mode: Graphics.Bitmap.Mode, shadowSize: Int) -> Graphics.DrawableId {
        dispatchPrecondition(condition: .onQueue(.main))
        let canvas = self.newCanvas(size: rect.size.cgSize(), mode: mode)
        let newView = CanvasView(canvas: canvas, shadowSize: shadowSize)
        newView.isHidden = true
        newView.frame = rect.cgRect()
        newView.delegate = self
        // Bit messy this, but it makes the code reuse better if we special case this (we can't add the default
        // window because this fn is called from within self.rootView's lazy construction).
        if canvas.id != .defaultWindow {
            self.rootView.addSubview(newView)
        }
        self.drawablesById[canvas.id] = newView
        self.windows[canvas.id] = newView
        bringInfoWindowToFront()
        return canvas.id
    }

    func createBitmap(size: Graphics.Size, mode: Graphics.Bitmap.Mode) -> Graphics.DrawableId {
        dispatchPrecondition(condition: .onQueue(.main))
        let canvas = newCanvas(size: size.cgSize(), mode: mode)
        drawablesById[canvas.id] = canvas
        return canvas.id
    }

    func setVisiblity(handle: Graphics.DrawableId, visible: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let view = self.window(for: handle) else {
            print("No CanvasView for showWindow operation")
            return
        }
        view.isHidden = !visible
    }

    /**
     N.B. In OPL terms position=1 means the front, whereas subviews[1] is at the back.
     */
    func order(drawableId: Graphics.DrawableId, position: Int) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let view = self.window(for: drawableId) else {
            return
        }
        let views = self.rootView.subviews
        let uipos = views.count - position
        if views.count == 0 || uipos < 0 {
            self.rootView.sendSubviewToBack(view)
        } else {
            self.rootView.insertSubview(view, aboveSubview: views[uipos])
        }
        bringInfoWindowToFront()
    }

    func close(drawableId: Graphics.DrawableId) {
        dispatchPrecondition(condition: .onQueue(.main))
        let view = self.window(for: drawableId)
        self.drawablesById[drawableId] = nil
        self.windows[drawableId] = nil
        if let view = view {
            view.removeFromSuperview()
        }

        // TODO: Clean up the sprites for this window.
    }

    func infoPrint(drawableId: Graphics.DrawableId) {
        dispatchPrecondition(condition: .onQueue(.main))
        hideInfoWindow()
        guard let canvas = self.window(for: drawableId) else {
            return
        }
        self.setVisiblity(handle: canvas.id, visible: true)
        infoDrawableHandle = canvas.id

        infoWindowDismissTimer = Timer.scheduledTimer(timeInterval: 2.0,
                                                      target: self,
                                                      selector: #selector(hideInfoWindow),
                                                      userInfo: nil,
                                                      repeats: false)
    }

    func busy(drawableId: Graphics.DrawableId, delay: Int) {
        dispatchPrecondition(condition: .onQueue(.main))
        cancelBusyTimer()
        guard let canvas = self.window(for: drawableId) else {
            return
        }
        busyDrawableHandle = canvas.id
        busyWindowShowTimer = Timer.scheduledTimer(timeInterval: Double(delay) / 1000,
                                                   target: self,
                                                   selector: #selector(showBusyWindow),
                                                   userInfo: nil,
                                                   repeats: false)
    }

    func setWin(drawableId: Graphics.DrawableId, position: Graphics.Point, size: Graphics.Size?) {
        dispatchPrecondition(condition: .onQueue(.main))
        if drawableId == Graphics.DrawableId.defaultWindow {
            // Let's ignore attempts to move/resize the toplevel window
        } else if let view = self.window(for: drawableId) {
            if let size = size {
                view.resize(to: size.cgSize())
            }
            view.frame = CGRect(origin: position.cgPoint(), size: view.frame.size)
        } else {
            print("No CanvasView for setwin operation")
        }
    }

    func clock(drawableId: Graphics.DrawableId, info: Graphics.ClockInfo?) {
        guard let view = self.window(for: drawableId) else {
            print("No CanvasView for clock operation")
            return
        }

        if let clockInfo = info {
            if view.clockView == nil {
                let v = ClockView(analogClockImage: device.analogClockImage,
                                  clockInfo: clockInfo,
                                  systemClockDigital: delegate!.windowServerClockIsDigital(self))
                view.clockView = v
                view.addSubview(v)
            }
            view.clockView?.clockInfo = clockInfo
        } else {
            if let clockView = view.clockView {
                clockView.removeFromSuperview()
                view.clockView = nil
            }
        }
        view.clockView?.clockChanged()
        if clockTimer == nil {
            let d = Calendar.current.nextDate(after: Date(), matching: DateComponents(second: 0), matchingPolicy: .nextTimePreservingSmallerComponents)!
            let timer = Timer(fireAt: d,
                              interval: 60,
                              target: self,
                              selector: #selector(clocksChanged),
                              userInfo: nil,
                              repeats: true)
            RunLoop.current.add(timer, forMode: .common)
            clockTimer = timer
        }
    }

    func setSprite(id: Int, sprite: Graphics.Sprite?) {
        dispatchPrecondition(condition: .onQueue(.main))
        // TODO: Start and stop the timer instead?
        if spriteTimer == nil {
            spriteTimer = Timer.scheduledTimer(timeInterval: 0.25,
                                               target: self,
                                               selector: #selector(tickSprites),
                                               userInfo: nil,
                                               repeats: true)
        }
        if let sprite = sprite,
           let spriteWindow = spriteWindows[id] {
            precondition(spriteWindow == sprite.window, "Sprites cannot move between windows!")
        }

        guard let drawableId = sprite?.window ?? spriteWindows[id] else {
            // A sprite we don't know about being deleted is kinda fine I guess...
            return
        }
        guard let drawable = self.drawablesById[drawableId] else {
            return
        }
        drawable.setSprite(sprite, for: id)
        if sprite == nil {
            spriteWindows.removeValue(forKey: id)
        }

    }

    func draw(operations: [Graphics.DrawCommand]) {
        for op in operations {
            guard let drawable = self.drawable(for: op.drawableId) else {
                print("No drawable for drawableId \(op.drawableId)!")
                continue
            }
            switch (op.type) {
            case .copy(let src, let mask):
                // These need some massaging to shoehorn in the src Drawable pointer
                guard let srcCanvas = self.drawable(for: src.drawableId) else {
                    print("Copy operation with unknown source \(src.drawableId)!")
                    continue
                }
                let newSrc = Graphics.CopySource(drawableId: src.drawableId, rect: src.rect, extra: srcCanvas.getImage())
                let newMaskSrc: Graphics.CopySource?
                if let mask = mask, let maskCanvas = self.drawable(for: mask.drawableId) {
                    newMaskSrc = Graphics.CopySource(drawableId: mask.drawableId, rect: mask.rect, extra: maskCanvas)
                } else {
                    newMaskSrc = nil
                }
                let newOp = Graphics.DrawCommand(drawableId: op.drawableId, type: .copy(newSrc, newMaskSrc),
                                                 mode: op.mode, origin: op.origin,
                                                 color: op.color, bgcolor: op.bgcolor, penWidth: op.penWidth)
                drawable.draw(newOp)
            case .pattern(let info):
                let extra: AnyObject?
                if info.drawableId.value == -1 {
                    guard let img = UIImage(named: "DitherPattern")?.cgImage else {
                        print("Failed to load DitherPattern!")
                        return
                    }
                    extra = img
                } else {
                    guard let srcCanvas = self.drawable(for: op.drawableId) else {
                        print("Pattern operation with unknown source \(info.drawableId)!")
                        continue
                    }
                    extra = srcCanvas.getImage()
                }
                // TODO: This is some special kind of garbage.
                let newInfo = Graphics.CopySource(drawableId: info.drawableId, rect: info.rect, extra: extra)
                let newOp = Graphics.DrawCommand(drawableId: op.drawableId, type: .pattern(newInfo),
                                                 mode: op.mode, origin: op.origin,
                                                 color: op.color, bgcolor: op.bgcolor, penWidth: op.penWidth)
                drawable.draw(newOp)
            default:
                drawable.draw(op)
            }
        }
    }

    private func bringInfoWindowToFront() {
        guard let infoDrawableHandle = infoDrawableHandle,
              let infoView = self.window(for: infoDrawableHandle)
        else {
            return
        }
        self.rootView.bringSubviewToFront(infoView)
    }

    @objc func hideInfoWindow() {
        guard let infoDrawableHandle = infoDrawableHandle else {
            return
        }
        setVisiblity(handle: infoDrawableHandle, visible: false)
        self.infoDrawableHandle = nil
        infoWindowDismissTimer?.invalidate()
    }

    func cancelBusyTimer() {
        busyWindowShowTimer?.invalidate()
        busyWindowShowTimer = nil
    }

    @objc func showBusyWindow() {
        cancelBusyTimer()
        guard let busyDrawableHandle = busyDrawableHandle else {
            return
        }
        setVisiblity(handle: busyDrawableHandle, visible: true)
        self.busyDrawableHandle = nil
    }

    @objc func tickSprites() {
        for drawable in self.drawablesById.values {
            drawable.updateSprites()
        }
    }

    func shutdown() {
        cancelBusyTimer()
        hideInfoWindow()
        spriteTimer?.invalidate()
        spriteTimer = nil
        clockTimer?.invalidate()
        clockTimer = nil
    }

    @objc func clocksChanged() {
        let isDigital = delegate!.windowServerClockIsDigital(self)
        for (_, window) in windows {
            window.clockView?.systemClockDigital = isDigital
            window.clockView?.clockChanged()
        }
    }

    public func systemClockFormatChanged(isDigital: Bool) {
        clocksChanged()
    }

    public func peekLine(drawableId: Graphics.DrawableId, position: Graphics.Point, numPixels: Int, mode: Graphics.PeekMode) -> Data {
        guard let canvas = self.drawablesById[drawableId],
              let image = canvas.getImage()
        else {
            print("Failed to get canvas image!")
            return Data()
        }
        var result = Data()
        let pixelData = image.dataProvider!.data!
        let ptr: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let offset = position.y * image.bytesPerRow + position.x // TODO flip needed?
        var bitIdx: Int = 0
        var currentByte: UInt8 = 0
        func addPixel(_ value: UInt8) {
            switch mode {
            case .oneBitBlack:
                currentByte |= (value == 0 ? 1 : 0) << bitIdx
                bitIdx += 1
            case .oneBitWhite:
                currentByte |= (value != 0 ? 1 : 0) << bitIdx
                bitIdx += 1
            case .twoBit:
                currentByte |= (value >> 6) << bitIdx
                bitIdx += 2
            case .fourBit:
                currentByte |= (value >> 4) << bitIdx
                bitIdx += 4
            }

            if bitIdx == 8 {
                result.append(currentByte)
                currentByte = 0
                bitIdx = 0
            }
        }

        if image.bitsPerPixel == 8 {
            // We only ever use 8bpp contexts in Canvas for greyscale images
            for i in 0 ..< numPixels {
                let px = ptr[offset + i]
                addPixel(px)
            }
        } else {
            for i in 0 ..< numPixels {
                let px = UInt32(ptr[offset + i]) + UInt32(ptr[offset + i]) + UInt32(ptr[offset + i + 1]) + UInt32(ptr[offset + i + 2])
                addPixel(UInt8(px / 3))
            }
        }
        if bitIdx != 0 {
            result.append(currentByte)
        }
        return result
    }

}

extension WindowServer: CanvasViewDelegate {

    func canvasView(_ canvasView: CanvasView, touchBegan touch: UITouch, with event: UIEvent) {
        delegate?.canvasView(canvasView, touchBegan: touch, with: event)
    }

    func canvasView(_ canvasView: CanvasView, touchMoved touch: UITouch, with event: UIEvent) {
        delegate?.canvasView(canvasView, touchMoved: touch, with: event)
    }

    func canvasView(_ canvasView: CanvasView, touchEnded touch: UITouch, with event: UIEvent) {
        delegate?.canvasView(canvasView, touchEnded: touch, with: event)
    }

    func canvasView(_ canvasView: CanvasView, insertCharacter character: Character) {
        delegate?.canvasView(canvasView, insertCharacter: character)
    }

    func canvasViewDeleteBackward(_ canvasView: CanvasView) {
        delegate?.canvasViewDeleteBackward(canvasView)
    }

    func canvasView(_ canvasView: CanvasView, sendKey key: OplKeyCode) {
        delegate?.canvasView(canvasView, sendKey: key)
    }

}
