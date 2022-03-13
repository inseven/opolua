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

    func windowServer(_ windowServer: WindowServer, insertCharacter character: Character)
    func windowServerDeleteBackward(_ windowServer: WindowServer)
    func windowServer(_ windowServer: WindowServer, sendKey key: OplKeyCode)

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
    private var drawablesById: [Graphics.DrawableId: Drawable] = [:]
    private var windows: [Graphics.DrawableId: CanvasView] = [:] // convenience
    private var infoDrawableHandle: Graphics.DrawableId?
    private var infoWindowDismissTimer: Timer?
    private var busyDrawableHandle: Graphics.DrawableId?
    private var busyWindowShowTimer: Timer?
    private var spriteTimer: Timer?
    private var clockTimer: Timer?

    // We run the timer at a fixed 0.05 (ie, 20Hz) interval on the basis that
    // the series 5 probably couldn't render anything faster than that anyway.
    private let kSpriteTimerInterval: TimeInterval = 0.05
    // Some games ask for an unreasonably small interval that the series 5
    // absolutely isn't able to honour - emperically this looks about right.
    private let kMinSpriteTime: TimeInterval = 0.1

    public var drawables: [Drawable] {
        return Array(drawablesById.values).sorted { $0.id.value < $1.id.value }
    }

    lazy var rootView: RootView = {
        let view = RootView(screenSize: screenSize.cgSize())
        return view
    }()

    init(device: Device, screenSize: Graphics.Size) {
        self.device = device
        self.screenSize = screenSize
        rootView.delegate = self
    }

    func drawable(for drawableId: Graphics.DrawableId) -> Drawable? {
        dispatchPrecondition(condition: .onQueue(.main))
        return drawablesById[drawableId]
    }

    func window(for drawableId: Graphics.DrawableId) -> CanvasView? {
        dispatchPrecondition(condition: .onQueue(.main))
        return windows[drawableId]
    }

    /**
     N.B. Windows are hidden by default.
     */
    func createWindow(id: Graphics.DrawableId, rect: Graphics.Rect, mode: Graphics.Bitmap.Mode, shadowSize: Int) {
        dispatchPrecondition(condition: .onQueue(.main))
        let canvas = Canvas(id: id, size: rect.size.cgSize(), mode: mode)
        let newView = CanvasView(canvas: canvas, shadowSize: shadowSize)
        newView.isHidden = true
        newView.frame = rect.cgRect()
        newView.delegate = self
        self.rootView.addSubview(newView)
        self.drawablesById[canvas.id] = newView
        self.windows[canvas.id] = newView
        bringInfoWindowToFront()
    }

    func createBitmap(id: Graphics.DrawableId, size: Graphics.Size, mode: Graphics.Bitmap.Mode) {
        dispatchPrecondition(condition: .onQueue(.main))
        let canvas = Canvas(id: id, size: size.cgSize(), mode: mode)
        drawablesById[canvas.id] = canvas
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

    func setSprite(window windowId: Graphics.DrawableId, id: Int, sprite: Graphics.Sprite?) {
        dispatchPrecondition(condition: .onQueue(.main))
        if sprite != nil && spriteTimer == nil {
            spriteTimer = Timer.scheduledTimer(timeInterval: kSpriteTimerInterval,
                                               target: self,
                                               selector: #selector(tickSprites(timer:)),
                                               userInfo: nil,
                                               repeats: true)
        }
        guard let window = self.windows[windowId] else {
            return
        }

        // Convert Graphics.Sprite to CanvasSprite
        let canvasSprite: CanvasSprite?
        if let sprite = sprite {
            var frames: [CanvasSprite.Frame] = []
            for frame in sprite.frames {
                if frame.bitmap.value == 0 || frame.mask.value == 0 {
                    // This is allowed, to make the SIBO sprite API work
                    continue
                }
                guard let bitmap = drawablesById[frame.bitmap],
                      let mask = drawablesById[frame.mask]
                else {
                    print("Bad bitmap/mask to setSprite!")
                    continue
                }
                frames.append(CanvasSprite.Frame(offset: frame.offset,
                                                 bitmap: bitmap,
                                                 mask: mask,
                                                 invertMask: frame.invertMask,
                                                 time: max(frame.time, kMinSpriteTime)))
            }
            canvasSprite = CanvasSprite(origin: sprite.origin, frames: frames)
        } else {
            canvasSprite = nil
        }

        window.setSprite(canvasSprite, for: id)
    }

    func draw(operations: [Graphics.DrawCommand]) {
        for op in operations {
            guard let drawable = self.drawable(for: op.drawableId) else {
                print("No drawable for drawableId \(op.drawableId)!")
                continue
            }
            drawable.draw(op, provider: self)
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

    @objc func tickSprites(timer: Timer) {
        var gotSprites = false
        for window in self.windows.values {
            if window.updateSprites(elapsedTime: timer.timeInterval) {
                gotSprites = true
            }
        }
        if !gotSprites {
            print("No more sprites, stopping timer")
            timer.invalidate()
            spriteTimer = nil
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

}

extension WindowServer: RootViewDelegate {

    func rootView(_ rootView: RootView, insertCharacter character: Character) {
        delegate?.windowServer(self, insertCharacter: character)
    }

    func rootViewDeleteBackward(_ rootView: RootView) {
        delegate?.windowServerDeleteBackward(self)
    }

    func rootView(_ rootView: RootView, sendKey key: OplKeyCode) {
        delegate?.windowServer(self, sendKey: key)
    }

}

extension WindowServer: DrawableImageProvider {

    func getImageFor(drawable: Graphics.DrawableId) -> CGImage? {
        guard let canvas = self.drawable(for: drawable) else {
            return nil
        }
        return canvas.getImage()
    }

}
