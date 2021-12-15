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


enum Task {

    case asyncRequest(Async.Request)
    case cancelRequest(Int32)

}

class ProgramViewController: UIViewController {

    enum State {
        case idle
        case running
    }

    let screenSize = Graphics.Size(width:640, height: 240)

    var object: OPLObject
    var procedureName: String?
    
    var state: State = .idle
    var nextHandle: Int
    var drawables: [Int: Drawable] = [:]

    let opo = OpoInterpreter()
    let runtimeQueue = DispatchQueue(label: "ScreenViewController.runtimeQueue")
    let eventQueue = ConcurrentQueue<Async.ResponseValue>()
    let scheduler = Scheduler()
    let handleGenerator = HandleGenerator(initialValue: 1000)

    let menu: ConcurrentBox<[UIMenuElement]> = ConcurrentBox()
    let menuCompletion: ConcurrentBox<(Int) -> Void> = ConcurrentBox()

    let tasks = ConcurrentQueue<Task>()
    let taskQueue = DispatchQueue(label: "ProgramViewController.taskQueue")
    
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

    init(object: OPLObject, procedureName: String? = nil) {
        self.object = object
        self.procedureName = procedureName
        self.nextHandle = 2
        super.init(nibName: nil, bundle: nil)
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground
        if let procedureName = procedureName {
            navigationItem.title = [object.name, procedureName].joined(separator: "\\")
        } else {
            navigationItem.title = object.name
        }
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

        scheduler.addHandler(.getevent) { request in
            // TODO: Cancellation isn't working right now.
            let value = self.eventQueue.takeFirst()
            // TODO: This whole service API is now somewhat janky as we know that it's there.
            self.scheduler.serviceRequest(type: request.type) { request in
                return Async.Response(requestHandle: request.requestHandle, value: value)
            }
        }
        scheduler.addHandler(.playsound) { request in
            print("PLAY SOUND!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.scheduler.serviceRequest(type: request.type) { request in
                    return Async.Response(requestHandle: request.requestHandle, value: .completed)
                }
            }
        }
        scheduler.addHandler(.sleep) { request in
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(request.intVal!) / 1000.0)) {
                self.scheduler.serviceRequest(type: request.type) { request in
                    return Async.Response(requestHandle: request.requestHandle, value: .completed)
                }
            }
        }

        let menuQueue = DispatchQueue(label: "ProgramViewController.menuQueue")
        
        let items = UIDeferredMenuElement.uncached { completion in
            menuQueue.async {
                self.eventQueue.sendMenu()
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
        // This implementation uses SPI to do just that by watching the notificaiton center for presentation dismiss
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

        canvasView.delegate = eventQueue

        taskQueue.async {
            // TODO: Have a way of terminating these queues?
            repeat {
                let task = self.tasks.takeFirst()
                switch task {
                case .asyncRequest(let request):
                    // print("Schedule Request")
                    self.scheduler.scheduleRequest(request)
                case .cancelRequest(let requestHandle):
                    self.scheduler.cancelRequest(requestHandle)
                }
            } while true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        start()
    }
    
    func start() {
        guard state == .idle else {
            return
        }
        state = .running
        runtimeQueue.async {
            self.opo.iohandler = self
            let url = self.object.url
            let appName = url.deletingPathExtension().lastPathComponent.uppercased()
            let oplPath = "C:\\SYSTEM\\APPS\\" + appName + "\\" + url.lastPathComponent
            let result = self.opo.run(devicePath: oplPath, procedureName: self.procedureName)
            DispatchQueue.main.async {
                self.programDidFinish(result: result)
            }
        }
    }
    
    func programDidFinish(result: OpoInterpreter.Result) {
        self.textView.textColor = .secondaryLabel
        switch result {
        case .none:
            self.textView.append("\n---Completed---")
        case .error(let err):
            self.textView.append("\n---Error occurred:---\n\(err.description)")
        }
    }

}

extension ProgramViewController: OpoIoHandler {

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

    func beep(frequency: Double, duration: Double) {
        // print("BEEP")
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
                newView.delegate = self.eventQueue
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

    func mapToNative(path: String) -> URL? {
        // For now assume if we're running foo.opo then we're running it from a simulated
        // C:\System\Apps\Foo\ path and make everything in the foo.opo dir available
        // under that path.
        let appName = object.url.deletingPathExtension().lastPathComponent
        let prefix = "C:\\SYSTEM\\APPS\\" + appName.uppercased() + "\\"
        if path.uppercased().starts(with: prefix) {
            let pathComponents = path.split(separator: "\\")[4...]
            var result = object.url.deletingLastPathComponent()
            for component in pathComponents {
                if component == "." || component == ".." {
                    continue
                }
                result.appendPathComponent(String(component))
            }
            return result.absoluteURL
        } else {
            return nil
        }
    }

    func fsop(_ op: Fs.Operation) -> Fs.Result {
        guard let nativePath = mapToNative(path: op.path) else {
            return .err(.notReady)
        }
        let path = nativePath.path
        // print("Got op for \(path)")
        let fm = FileManager.default
        switch (op.type) {
        case .exists:
            let exists = fm.fileExists(atPath: path)
            return .err(exists ? .alreadyExists : .notFound)
        case .delete:
            // Should probably prevent this from accidentally deleting a directory...
            do {
                try fm.removeItem(atPath: path)
                return .err(.none)
            } catch {
                return .err(.notReady)
            }
        case .mkdir:
            print("TODO mkdir \(path)")
        case .rmdir:
            print("TODO rmdir \(path)")
        case .write(let data):
            let ok = fm.createFile(atPath: path, contents: data)
            return .err(ok ? .none : .notReady)
        case .read:
            if let result = fm.contents(atPath: nativePath.path) {
                return .data(result)
            } else if !fm.fileExists(atPath: path) {
                return .err(.notFound)
            } else {
                return .err(.notReady)
            }
        }
        return .err(.notReady)
    }

    func asyncRequest(_ request: Async.Request) {
        tasks.append(.asyncRequest(request))
    }

    func cancelRequest(_ requestHandle: Int32) {
        scheduler.cancelRequest(requestHandle)
    }

    func waitForAnyRequest() -> Async.Response {
        return scheduler.waitForAnyRequest()
    }

    func anyRequest() -> Async.Response? {
        return scheduler.anyRequest()
    }

    func key() -> KeyCode? {
        // TODO return non-nil (and remove the event from the queue) if there's
        // any KeyPressEvent in the queue
        return nil
    }

}

extension ConcurrentQueue: CanvasViewDelegate where T == Async.ResponseValue {

    private func handleTouch(_ touch: UITouch, in view: CanvasView, with event: UIEvent, type: Async.PenEventType) {
        let location = touch.location(in: view)
        let screenLocation = touch.location(in: view.superview)
        append(.penevent(.init(timestamp: Int(event.timestamp),
                               windowId: view.id,
                               type: type,
                               modifiers: 0,
                               x: Int(location.x),
                               y: Int(location.y),
                               screenx: Int(screenLocation.x),
                               screeny: Int(screenLocation.y))))
    }

    func canvasView(_ canvasView: CanvasView, touchBegan touch: UITouch, with event: UIEvent) {
        handleTouch(touch, in: canvasView, with: event, type: .down)
    }

    func canvasView(_ canvasView: CanvasView, touchMoved touch: UITouch, with event: UIEvent) {
        handleTouch(touch, in: canvasView, with: event, type: .drag)
    }

    func canvasView(_ canvasView: CanvasView, touchEnded touch: UITouch, with event: UIEvent) {
        handleTouch(touch, in: canvasView, with: event, type: .up)
    }

}

extension ConcurrentQueue where T == Async.ResponseValue {

    func sendKeyPress(_ key: KeyCode) {
        append(.keypressevent(.init(timestamp: Int(NSDate().timeIntervalSince1970),
                                    keycode: key,
                                    modifiers: Modifiers(),
                                    isRepeat: false)))
    }

    func sendMenu() {
        // TODO: Review injected key behaviour
        // Vexed doesn't seem to expect the key down and key up events surrounding the key press so, for the time being,
        // we're only sending the key press event. It's quite possible that Vexed is failing to consume the down/up
        // events due to a bug in our event queue, but either way, I suspect skipping these down/up events will cause
        // problems in other programs.
        sendKeyPress(.menu)
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
                return UIAction(title: item.text) { action in
                    completion(item.keycode)
                }
            }
        }
    }

}
