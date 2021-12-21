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

class ProgramViewController: UIViewController {

    let screenSize = Graphics.Size(width:640, height: 240)

    var program: Program
    
    var nextHandle: Int
    var drawables: [Int: Drawable] = [:]

    let menu: ConcurrentBox<[UIMenuElement]> = ConcurrentBox()
    let menuCompletion: ConcurrentBox<(Int) -> Void> = ConcurrentBox()
    
    lazy var textView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        return textView
    }()

    lazy var canvasView: CanvasView = {
        let canvas = CanvasView(id: 1, size: screenSize.cgSize())
        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.layer.borderWidth = 1.0
        canvas.layer.borderColor = UIColor.black.cgColor
        canvas.clipsToBounds = true
        drawables[1] = canvas // 1 is always the main window
        return canvas
    }()

    init(program: Program) {
        self.program = program
        self.nextHandle = 2
        super.init(nibName: nil, bundle: nil)
        program.delegate = self
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground
        navigationItem.title = program.name
        view.clipsToBounds = true
        view.addSubview(canvasView)
        view.addSubview(textView)
        NSLayoutConstraint.activate([

            canvasView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            canvasView.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            textView.topAnchor.constraint(equalTo: canvasView.bottomAnchor, constant: 8.0),
            textView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),

        ])

        let menuQueue = DispatchQueue(label: "ProgramViewController.menuQueue")
        
        let items = UIDeferredMenuElement.uncached { completion in
            menuQueue.async {
                self.program.sendMenu()
                let disabled = UIAction(title: "None", attributes: .disabled) { _ in }
                let items = self.menu.tryTake(until: Date().addingTimeInterval(0.1)) ?? [disabled]
                DispatchQueue.main.async {
                    completion(items)
                }
            }
        }
        let menu = UIMenu(title: "", image: nil, identifier: nil, options: [], children: [items])
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: nil,
                                                            image: UIImage(systemName: "ellipsis.circle"),
                                                            primaryAction: nil,
                                                            menu: menu)

        // Unfortunately there doesn't seem to be a great way to detect when the user dismisses the menu.
        // This implementation uses SPI to do just that by watching the notification center for presentation dismiss
        // notifications and ignores notifications for anything that isn't a menu.
        let UIPresentationControllerDismissalTransitionDidEndNotification = NSNotification.Name(rawValue: "UIPresentationControllerDismissalTransitionDidEndNotification")
        NotificationCenter.default.addObserver(forName: UIPresentationControllerDismissalTransitionDidEndNotification,
                                               object: nil,
                                               queue: .main) { notification in
            guard let UIContextMenuActionsOnlyViewController = NSClassFromString("_UIContextMenuActionsOnlyViewController"),
                  let object = notification.object,
                  type(of: object) == UIContextMenuActionsOnlyViewController
            else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.menuCompletion.tryTake()?(0)
            }
        }

        canvasView.delegate = program
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        program.start()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key {
                let timestamp = Int(press.timestamp)
                let modifiers = key.oplModifiers()

                let (keydownCode, keypressCode) = key.toOplCodes()

                // The could be no legitimate keydownCode if we're inputting say
                // a tilde which is not on a key that the Psion 5 keyboard has
                if let code = keydownCode {
                    program.sendEvent(.keydownevent(.init(timestamp: timestamp, keycode: code, modifiers: modifiers)))
                } else {
                    print("No keydown code for \(key)")
                }

                if let code = keypressCode, code.toCharcode() != nil {
                    let event = Async.KeyPressEvent(timestamp: timestamp, keycode: code, modifiers: modifiers, isRepeat: false)
                    if event.modifiedKeycode() != nil {
                        program.sendEvent(.keypressevent(event))
                    }
                } else {
                    print("No keypress code for \(key)")
                }
            }
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key {
                let (oplKey, _) = key.toOplCodes()
                if let oplKey = oplKey {
                    let timestamp = Int(press.timestamp)
                    let modifiers = key.oplModifiers()
                    program.sendEvent(.keyupevent(.init(timestamp: timestamp, keycode: oplKey, modifiers: modifiers)))
                }
            }
        }
    }

}

extension ProgramViewController: ProgramDelegate {

    func program(_ program: Program, didFinishWithResult result: OpoInterpreter.Result) {
        self.textView.textColor = .secondaryLabel
        switch result {
        case .none:
            self.textView.append("\n---Completed---")
        case .error(let err):
            self.textView.append("\n---Error occurred:---\n\(err.description)")
        }
    }

    func program(_ program: Program, didEncounterError error: Error) {
        present(error: error)
    }

    func printValue(_ val: String) {
        DispatchQueue.main.async {
            self.textView.append(val)
        }
    }
    
    func readLine(escapeShouldErrorEmptyInput: Bool) -> String? {
        // TODO
        return "123" // Have to return something valid here otherwise INPUT might keep on asking us
    }
    
    func alert(lines: [String], buttons: [String]) -> Int {
        let semaphore = DispatchSemaphore(value: 0)
        var result = 1
        DispatchQueue.main.async {
            let message = lines.joined(separator: "\n")
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            if buttons.count > 0 {
                for (index, button) in buttons.enumerated() {
                    alert.addAction(.init(title: button, style: .default) { action in
                        result = index + 1
                        semaphore.signal()
                    })
                }
            } else {
                alert.addAction(.init(title: "Continue", style: .default) { action in
                    semaphore.signal()
                })
            }
            self.present(alert, animated: true, completion: nil)
        }
        semaphore.wait()
        return result
    }

    func dialog(_ dialog: Dialog) -> Dialog.Result {
        let semaphore = DispatchSemaphore(value: 0)
        var result = Dialog.Result(result: 0, values: [])
        DispatchQueue.main.async {
            result = Dialog.Result(result: 0, values: [])
            let viewController = DialogViewController(dialog: dialog) { key, values in
                result = Dialog.Result(result: key, values: values)
                semaphore.signal()
            }
            let navigationController = UINavigationController(rootViewController: viewController)
            self.present(navigationController, animated: true)
        }
        semaphore.wait()
        return result
    }

    func menu(_ menu: Menu.Bar) -> Menu.Result {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Menu.Result = .none
        self.menuCompletion.put { keycode in
            result = Menu.Result(selected: keycode, highlighted: keycode)
            semaphore.signal()
        }
        self.menu.put(menu.menuElements { keycode in
            self.menuCompletion.tryTake()?(keycode)
        })
        semaphore.wait()
        return result
    }

    func draw(operations: [Graphics.DrawCommand]) {
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            for op in operations {
                guard let drawable = self.drawables[op.displayId] else {
                    print("No drawable for displayid \(op.displayId)!")
                    continue
                }

                switch (op.type) {
                case .copy(let src, let mask):
                    // These need some massaging to shoehorn in the src Drawable pointer
                    guard let srcCanvas = self.drawables[src.displayId] else {
                        print("Copy operation with unknown source \(src.displayId)!")
                        continue
                    }
                    let newSrc = Graphics.CopySource(displayId: src.displayId, rect: src.rect, extra: srcCanvas)
                    let newMaskSrc: Graphics.CopySource?
                    if let mask = mask, let maskCanvas = self.drawables[mask.displayId] {
                        newMaskSrc = Graphics.CopySource(displayId: mask.displayId, rect: mask.rect, extra: maskCanvas)
                    } else {
                        newMaskSrc = nil
                    }
                    let newOp = Graphics.DrawCommand(displayId: op.displayId, type: .copy(newSrc, newMaskSrc),
                                                     mode: op.mode, origin: op.origin,
                                                     color: op.color, bgcolor: op.bgcolor)
                    drawable.draw(newOp)
                default:
                    drawable.draw(op)
                }

            }

            semaphore.signal()
        }
        semaphore.wait()
    }

    func graphicsop(_ operation: Graphics.Operation) -> Graphics.Result {
        let semaphore = DispatchSemaphore(value: 0)
        switch (operation) {
        case .createBitmap(let size):
            var h = 0
            DispatchQueue.main.async {
                h = self.nextHandle
                self.nextHandle += 1
                let color = false // Hardcoded, for the moment
                self.drawables[h] = Canvas(size: size.cgSize(), color: color)
                semaphore.signal()
            }
            semaphore.wait()
            return .handle(h)
        case .createWindow(let rect, let shadowSize):
            var h = 0
            DispatchQueue.main.async {
                h = self.nextHandle
                self.nextHandle += 1
                let newView = CanvasView(id: h, size: rect.size.cgSize(), shadowSize: shadowSize)
                newView.isHidden = true // by default, will get a showWindow op if needed
                newView.frame = rect.cgRect()
                newView.delegate = self.program
                self.canvasView.addSubview(newView)
                self.drawables[h] = newView
                semaphore.signal()
            }
            semaphore.wait()
            return .handle(h)
        case .close(let displayId):
            DispatchQueue.main.async {
                if let view = self.drawables[displayId] as? CanvasView {
                    view.removeFromSuperview()
                }
                self.drawables[displayId] = nil
                semaphore.signal()
            }
            semaphore.wait()
            return .nothing
        case .order(let displayId, let position):
            DispatchQueue.main.async {
                if let view = self.drawables[displayId] as? CanvasView {
                    // In OPL terms position=1 means the front, whereas subviews[1] is at the back
                    let views = self.canvasView.subviews
                    let uipos = views.count - position
                    if views.count == 0 || uipos < 0 {
                        self.canvasView.sendSubviewToBack(view)
                    } else {
                        self.canvasView.insertSubview(view, aboveSubview: views[uipos])
                    }
                }
                semaphore.signal()
            }
            semaphore.wait()
            return .nothing
        case .show(let displayId, let flag):
            DispatchQueue.main.async {
                if let view = self.drawables[displayId] as? CanvasView {
                    view.isHidden = !flag
                } else {
                    print("No CanvasView for showWindow operation")
                }
                semaphore.signal()
            }
            semaphore.wait()
            return .nothing
        case .textSize(let string, let fontInfo):
            let font = fontInfo.toUiFont()
            let attribStr = NSAttributedString(string: string, attributes: [.font: font])
            let sz = attribStr.size()
            // This is not really the right definition for ascent but it seems to work for where epoc expects
            // the text to be, so...
            let ascent = Int(ceil(sz.height) + font.descender)
            return .sizeAndAscent(Graphics.Size(width: Int(ceil(sz.width)), height: Int(ceil(sz.height))), ascent)
        case .busy(let text, _, _ /*let corner, let delay*/):
            // TODO
            if text.count > 0 {
                printValue(text)
            }
            return .nothing
        case .giprint(let text, _ /*let corner*/):
            // TODO
            printValue(text + "\n")
            return .nothing
        case .setwin(let displayId, let pos, let size):
            DispatchQueue.main.async {
                if let view = self.drawables[displayId] as? CanvasView {
                    if let size = size {
                        view.resize(to: size.cgSize())
                    }
                    view.frame = CGRect(origin: pos.cgPoint(), size: view.frame.size)
                } else {
                    print("No CanvasView for setwin operation")
                }
                semaphore.signal()
            }
            semaphore.wait()
            return .nothing
        }
    }

    func getScreenSize() -> Graphics.Size {
        return screenSize
    }

    func key() -> OplKeyCode? {
        // TODO return non-nil (and remove the event from the queue) if there's
        // any KeyPressEvent in the queue
        return nil
    }

}

extension Menu.Bar {

    func menuElements(completion: @escaping (Int) -> Void) -> [UIMenuElement] {
        return menus.map { menu in
            return UIMenu(title: menu.title, children: menu.menuElements(completion: completion))
        }

    }

}

extension Menu {

    func menuElements(completion: @escaping (Int) -> Void) -> [UIMenuElement] {
        return items.map { item in
            if let submenu = item.submenu {
                return UIMenu(title: submenu.title, children: submenu.menuElements(completion: completion))
            } else {
                return UIAction(title: item.text, subtitle: item.shortcut) { action in
                    completion(item.keycode)
                }
            }
        }
    }

}
