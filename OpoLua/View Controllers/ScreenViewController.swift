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

class ScreenViewController: UIViewController {
    
    enum State {
        case idle
        case running
    }

    var object: OPLObject
    var procedureName: String?
    
    var state: State = .idle
    var nextHandle: Int
    var drawables: [Int: Drawable] = [:]

    let opo = OpoInterpreter()
    let runtimeQueue = DispatchQueue(label: "ScreenViewController.runtimeQueue")

    var getEventHandle: Int32? = nil

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

        let sz = getScreenSize().cgSize()
        let canvas = CanvasView(size: sz)
        canvas.translatesAutoresizingMaskIntoConstraints = false
        drawables[1] = canvas // 1 is always the main window

        view.addSubview(canvas)
        view.addSubview(textView)
        NSLayoutConstraint.activate([

            canvas.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),

            textView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),
        ])
        
        setToolbarItems([menuBarButtonItem], animated: false)
        menuBarButtonItem.isEnabled = false
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
        // navigationController?.popViewController(animated: true)
        self.textView.backgroundColor = UIColor.lightGray
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

extension ScreenViewController: OpoIoHandler {

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
        return Graphics.Size(width:640, height: 240)
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
        print("Got op for \(nativePath.path)")
        let fm = FileManager.default
        switch (op.type) {
        case .exists:
            let exists = fm.fileExists(atPath: path)
            return .err(exists ? .alreadyExists : .notFound)
        case .delete:
            print("TODO delete")
        case .mkdir:
            print("TODO mkdir")
        case .rmdir:
            print("TODO rmdir")
        case .write(_):
            print("TODO write")
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
        if request.type == .getevent {
            getEventHandle = request.requestHandle
        }
    }

    func waitForAnyRequest() -> Async.Response {
        fatalError("waitForAnyRequest not implemented yet!")
    }

    func createBitmap(width: Int, height: Int) -> Int? {
        let h = self.nextHandle
        self.nextHandle += 1
        drawables[h] = Canvas(size: CGSize(width: width, height: height))
        return h
    }
}
