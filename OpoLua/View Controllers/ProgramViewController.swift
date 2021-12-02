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


extension Dictionary {

    mutating func removeRandomValue() -> Value? {
        guard let element = self.randomElement() else {
            return nil
        }
        return removeValue(forKey: element.key)
    }

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
    let scheduler = Scheduler()

    var getCompletion: ((Int) -> Void)? {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            menuBarButtonItem.isEnabled = (getCompletion != nil)
        }
    }
    
    lazy var textView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        return textView
    }()
    
    lazy var menuBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "filemenu.and.selection"),
                                            style: .plain,
                                            target: self,
                                            action: #selector(menuTapped(sender:)))
        return barButtonItem
    }()

    lazy var canvasView: CanvasView = {
        let canvas = CanvasView(size: screenSize.cgSize())
        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.layer.borderWidth = 1.0
        canvas.layer.borderColor = UIColor.black.cgColor
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
        
        setToolbarItems([menuBarButtonItem], animated: false)
        menuBarButtonItem.isEnabled = false

        canvasView.delegate = scheduler
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = false
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
            let result = self.opo.run(file: self.object.url.path, procedureName: self.procedureName)
            DispatchQueue.main.async {
                self.programDidFinish(result: result)
            }
        }
    }
    
    func programDidFinish(result: OpoInterpreter.Result) {
        self.textView.textColor = .secondaryLabel
        switch result {
        case .none:
            self.textView.text?.append("\n---Completed---")
        case .error(let err):
            self.textView.text?.append("\n---Error occurred:---\n\(err.description)")
        }
    }

    @objc func menuTapped(sender: UIBarButtonItem) {
        getCompletion?(KeyCode.menu.rawValue)
    }

}

extension ProgramViewController: OpoIoHandler {

    func printValue(_ val: String) {
        DispatchQueue.main.async {
            self.textView.text?.append(val)
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
    
    func getch() -> Int {
        let semaphore = DispatchSemaphore(value: 0)
        var keyCode = 0
        DispatchQueue.main.async {
            self.getCompletion = { result in
                keyCode = result
                self.getCompletion = nil
                semaphore.signal()
            }
        }
        semaphore.wait()
        return keyCode
    }
    
    func beep(frequency: Double, duration: Double) {
        print("BEEP")
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
        DispatchQueue.main.async {
            let viewController = MenuViewController(title: "Menu", menu: menu) { item in
                if let item = item {
                    result = Menu.Result(selected: item.keycode, highlighted: item.keycode)
                }
                semaphore.signal()
            }
            let navigationController = TranslucentNavigationController(rootViewController: viewController)
            if #available(iOS 15.0, *) {
                if let presentationController = navigationController.presentationController
                    as? UISheetPresentationController {
                    presentationController.detents = [.medium(), .large()]
                }
            }
            self.present(navigationController, animated: true)
        }
        semaphore.wait()
        return result
    }

    func draw(operations: [Graphics.Operation]) {
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            // Split ops into per drawable
            // TODO this is all a bit broken atm allowing out-of-order execution of ops :-(

            var opsPerId: [Int: [Graphics.Operation]] = [:]
            for op in operations {
                if opsPerId[op.displayId] == nil {
                    opsPerId[op.displayId] = []
                }
                switch (op.type) {
                case .copy(let src):
                    // These need some massaging to shoehorn in the src Drawable pointer
                    guard let srcCanvas = self.drawables[src.displayId] else {
                        print("Copy operation with unknown source \(src.displayId)!")
                        continue
                    }
                    let newSrc = Graphics.CopySource(displayId: src.displayId, rect: src.rect, extra: srcCanvas)
                    let newOp = Graphics.Operation(displayId: op.displayId, type: .copy(newSrc),
                                                   origin: op.origin, color: op.color, bgcolor: op.bgcolor)
                    opsPerId[op.displayId]!.append(newOp)
                case .showWindow(let flag):
                    guard let view = self.drawables[op.displayId] as? CanvasView else {
                        print("No CanvasView for showWindow operation")
                        continue
                    }
                    view.isHidden = !flag
                default:
                    opsPerId[op.displayId]!.append(op)
                }

            }
            for (id, ops) in opsPerId  {
                if let drawable = self.drawables[id] {
                    drawable.draw(ops)
                } else {
                    print("\(ops.count) operations for unknown displayId!")
                }
            }

            semaphore.signal()
        }
        semaphore.wait()
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
        scheduler.scheduleRequest(request)
    }

    func cancelRequest(_ requestHandle: Int32) {
        // TODO
    }

    func waitForAnyRequest() -> Async.Response {
        return scheduler.waitForAnyRequest()
    }

    func createBitmap(size: Graphics.Size) -> Int? {
        var h = 0
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            h = self.nextHandle
            self.nextHandle += 1
            self.drawables[h] = Canvas(size: size.cgSize())
            semaphore.signal()
        }
        semaphore.wait()
        return h
    }

    func createWindow(rect: Graphics.Rect) -> Int? {
        var h = 0
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            h = self.nextHandle
            self.nextHandle += 1
            let newView = CanvasView(size: rect.size.cgSize())
            newView.isHidden = true // by default, will get a showWindow op if needed
            newView.frame = rect.cgRect()
            self.canvasView.addSubview(newView)
            self.drawables[h] = newView
            semaphore.signal()
        }
        semaphore.wait()
        return h
    }
}

extension Scheduler: CanvasViewDelegate {

    func canvasView(_ canvasView: CanvasView, touchesBegan touches: Set<UITouch>, with event: UIEvent?) {
        guard let event = event else {
            return
        }
        serviceRequest(type: .getevent) { request in

            // TODO: WindowID
            let event = Async.PenEvent(timestamp: Int(event.timestamp),
                                       windowId: 1,
                                       type: .down,
                                       modifiers: 0,
                                       x: 0,
                                       y: 0)
            return Async.Response(type: .getevent,
                                  requestHandle: request.requestHandle,
                                  value: .penevent(event))
        }
    }

    func canvasView(_ canvasView: CanvasView, touchesMoved touches: Set<UITouch>, with event: UIEvent?) {
        // TODO: Implement me
    }

    func canvasView(_ canvasView: CanvasView, touchesEnded touches: Set<UITouch>, with event: UIEvent?) {
        // TODO: Implement me
    }


}
