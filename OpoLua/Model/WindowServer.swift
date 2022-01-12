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

class WindowServer {

    // TODO: Move this up into the Opo layer
    struct TextDetails {
        let size: Graphics.Size
        let ascent: Int
    }

    static func textSize(string: String, fontInfo: Graphics.FontInfo) -> TextDetails {
        if let font = fontInfo.toBitmapFont() {
            let renderer = BitmapFontRenderer(font: font)
            let (w, h) = renderer.getTextSize(string)
            return TextDetails(size: Graphics.Size(width: w, height: h), ascent: font.ascent)
        } else {
            let font = fontInfo.toUiFont()! // One or other has to return non-nil
            let attribStr = NSAttributedString(string: string, attributes: [.font: font])
            let sz = attribStr.size()
            // This is not really the right definition for ascent but it seems to work for where epoc expects
            // the text to be, so...
            let ascent = Int(ceil(sz.height) + font.descender)
            return TextDetails(size: Graphics.Size(width: Int(ceil(sz.width)), height: Int(ceil(sz.height))),
                               ascent: ascent)
        }
    }

    // TODO: This should probably be done by a delegate model.
    private var program: Program

    private var drawableHandle = (1...).makeIterator()
    private var drawables: [Graphics.DrawableId: Drawable] = [:]

    private var infoDrawableHandle: Graphics.DrawableId?
    private var infoWindowDismissTimer: Timer?
    private var busyDrawableHandle: Graphics.DrawableId?
    private var busyWindowShowTimer: Timer?

    var sprites: [Int: Sprite] = [:]
    var spriteTimer: Timer?

    lazy var canvasView: CanvasView = {
        let canvas = newCanvas(size: program.screenSize.cgSize(), color: true)
        let canvasView = CanvasView(canvas: canvas)
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.layer.borderWidth = 1.0
        canvasView.layer.borderColor = UIColor.lightGray.cgColor
        canvasView.clipsToBounds = true
        canvasView.delegate = program
        drawables[.defaultWindow] = canvasView
        return canvasView
    }()

    init(program: Program) {
        self.program = program
    }

    func drawable(for drawableId: Graphics.DrawableId) -> Drawable? {
        dispatchPrecondition(condition: .onQueue(.main))
        return drawables[drawableId]
    }

    private func newCanvas(size: CGSize, color: Bool) -> Canvas {
        dispatchPrecondition(condition: .onQueue(.main))
        let id = Graphics.DrawableId(value: drawableHandle.next()!)
        let canvas = Canvas(windowServer: self, id: id, size: size, color: color)
        return canvas
    }

    /**
     N.B. Windows are hidden by default.
     */
    func createWindow(rect: Graphics.Rect, mode: Graphics.Bitmap.Mode, shadowSize: Int) -> Canvas {
        dispatchPrecondition(condition: .onQueue(.main))
        let isColor = mode == .Color16 || mode == .Color256
        let canvas = self.newCanvas(size: rect.size.cgSize(), color: isColor)
        let newView = CanvasView(canvas: canvas, shadowSize: shadowSize)
        newView.isHidden = true
        newView.frame = rect.cgRect()
        newView.delegate = self.program
        self.canvasView.addSubview(newView)
        self.drawables[canvas.id] = newView
        bringInfoWindowToFront()
        return canvas
    }

    func createBitmap(size: Graphics.Size, mode: Graphics.Bitmap.Mode) -> Canvas {
        dispatchPrecondition(condition: .onQueue(.main))
        let isColor = mode == .Color16 || mode == .Color256
        let canvas = newCanvas(size: size.cgSize(), color: isColor)
        drawables[canvas.id] = canvas
        return canvas
    }

    func setVisiblity(handle: Graphics.DrawableId, visible: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let view = self.drawables[handle] as? CanvasView else {
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
        guard let view = self.drawables[drawableId] as? CanvasView else {
            return
        }
        let views = self.canvasView.subviews
        let uipos = views.count - position
        if views.count == 0 || uipos < 0 {
            self.canvasView.sendSubviewToBack(view)
        } else {
            self.canvasView.insertSubview(view, aboveSubview: views[uipos])
        }
        bringInfoWindowToFront()
    }

    func close(drawableId: Graphics.DrawableId) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let view = self.drawables[drawableId] as? CanvasView else {
            return
        }
        view.removeFromSuperview()
        self.drawables[drawableId] = nil

        // TODO: Clean up the sprites for this window.
    }

    func infoPrint(drawableId: Graphics.DrawableId) {
        dispatchPrecondition(condition: .onQueue(.main))
        hideInfoWindow()
        guard let canvas = self.drawables[drawableId] as? CanvasView else {
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
        guard let canvas = self.drawables[drawableId] as? CanvasView else {
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
        } else if let view = self.drawables[drawableId] as? CanvasView {
            if let size = size {
                view.resize(to: size.cgSize())
            }
            view.frame = CGRect(origin: position.cgPoint(), size: view.frame.size)
        } else {
            print("No CanvasView for setwin operation")
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
        guard let sprite = sprite else {
            // TODO: Delete sprites from the windows!
            // TODO: We'll need to nuke these sprites when the windows are deleted.
            sprites.removeValue(forKey: id)
            return
        }
        guard let drawable = self.drawables[sprite.window] else {
            return
        }
        drawable.setSprite(sprite, for: id)
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
              let infoView = self.drawables[infoDrawableHandle] as? CanvasView
        else {
            return
        }
        self.canvasView.bringSubviewToFront(infoView)
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
        for drawable in self.drawables.values {
            drawable.updateSprites()
        }
    }

    func shutdown() {
        cancelBusyTimer()
        hideInfoWindow()
        spriteTimer?.invalidate()
        spriteTimer = nil
    }

}
