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

import UIKit

protocol ProgramDelegate: AnyObject {

    func program(_ program: Program, didFinishWithResult result: OpoInterpreter.Result)
    func program(_ program: Program, didEncounterError error: Error)
    func program(_ program: Program, didUpdateTitle title: String)
    func readLine(escapeShouldErrorEmptyInput: Bool) -> String?
    func program(_ program: Program, showAlertWithLines lines: [String], buttons: [String]) -> Int
    func dialog(_ d: Dialog) -> Dialog.Result
    func menu(_ m: Menu.Bar) -> Menu.Result

}

class Program {

    enum State {
        case idle
        case running
        case finished
    }

    class GetEventRequest: Scheduler.Request {
        weak var program: Program?

        init(handle: Async.RequestHandle, program: Program) {
            self.program = program
            super.init(handle: handle)
        }

        override func cancel() {
            if let prog = program {
                prog.geteventRequest = nil
            }
        }

        override func start() {
            guard let program = self.program else {
                print("Cannot start request if program isn't set!")
                return
            }
            program.startGetEventRequest(self)
        }
    }

    private let url: URL
    private let procedureName: String?
    private let device: Device
    private let thread: InterpreterThread
    private let eventQueue = ConcurrentQueue<Async.ResponseValue>()
    let windowServer: WindowServer
    private let scheduler = Scheduler()
    fileprivate var geteventRequest: GetEventRequest?

    private var _state: State = .idle

    private var oplConfig: [ConfigName: String] = [:]

    public var state: State {
        return _state
    }

    weak var delegate: ProgramDelegate?

    var console = Console()

    var title: String

    var rootView: UIView {
        return windowServer.canvasView
    }

    lazy private var fileSystem: FileSystem = {
        do {
            return try FileManager.default.detectSystemFileSystem(for: url) ?? ObjectFileSystem(objectUrl: url)
        } catch {
            return ObjectFileSystem(objectUrl: url)
        }
    }()

    init(url: URL, procedureName: String? = nil, device: Device = .psionSeries5) {
        self.url = url
        self.procedureName = procedureName
        self.device = device
        self.title = Directory.appInfo(forApplicationUrl: url)?.caption ?? url.name
        self.thread = InterpreterThread(url: url, procedureName: procedureName)
        self.windowServer = WindowServer(screenSize: device.screenSize)
        self.thread.delegate = self
        self.thread.handler = self
        self.windowServer.delegate = self
        for key in ConfigName.allCases {
            switch key {
            case .clockFormat:
                oplConfig[key] = "0" // analog
            }
        }
    }

    func start() {
        guard state == .idle else {
            return
        }
        _state = .running
        thread.start()
    }

    func toggleOnScreenKeyboard() {
        if windowServer.canvasView.isFirstResponder {
            windowServer.canvasView.resignFirstResponder()
        } else {
            windowServer.canvasView.becomeFirstResponder()
        }
    }

    func sendMenu() {
        sendKey(.menu)
    }

    func sendKeyDown(_ key: OplKeyCode) {
        let timestamp = ProcessInfo.processInfo.systemUptime
        sendEvent(.keydownevent(.init(timestamp: timestamp,
                                      keycode: key,
                                      modifiers: Modifiers())))
    }

    func sendKeyUp(_ key: OplKeyCode) {
        let timestamp = ProcessInfo.processInfo.systemUptime
        sendEvent(.keyupevent(.init(timestamp: timestamp,
                                    keycode: key,
                                    modifiers: Modifiers())))
    }

    func sendKeyPress(_ key: OplKeyCode) {
        let timestamp = ProcessInfo.processInfo.systemUptime
        sendEvent(.keypressevent(.init(timestamp: timestamp,
                                       keycode: key,
                                       modifiers: Modifiers(),
                                       isRepeat: false)))
    }

    func sendKey(_ key: OplKeyCode) {
        sendKeyDown(key)
        sendKeyPress(key)
        sendKeyUp(key)
    }

    func sendEvent(_ event: Async.ResponseValue) {
        eventQueue.append(event)
        checkGetEventCompletion()
    }

    func startGetEventRequest(_ request: GetEventRequest) {
        scheduler.withLockHeld {
            precondition(self.geteventRequest == nil, "Duplicate geteventRequest!")
            self.geteventRequest = request
        }
        checkGetEventCompletion()
    }

    func checkGetEventCompletion() {
        scheduler.withLockHeld {
            if let request = self.geteventRequest,
               let event = eventQueue.first() {
                self.geteventRequest = nil
                scheduler.completeLocked(request: request, response: event)
            }
        }
    }

    private func performGraphicsOperation(_ operation: Graphics.Operation) -> Graphics.Result {
        dispatchPrecondition(condition: .onQueue(.main))
        switch (operation) {

        case .createBitmap(let size, let mode):
            let id = windowServer.createBitmap(size: size, mode: mode)
            return .handle(id)

        case .createWindow(let rect, let mode, let shadowSize):
            let id = windowServer.createWindow(rect: rect, mode: mode, shadowSize: shadowSize)
            return .handle(id)

        case .close(let drawableId):
            windowServer.close(drawableId: drawableId)
            return .nothing

        case .order(let drawableId, let position):
            windowServer.order(drawableId: drawableId, position: position)
            return .nothing

        case .show(let drawableId, let flag):
            windowServer.setVisiblity(handle: drawableId, visible: flag)
            return .nothing

        case .textSize(let string, let fontInfo):
            let details = WindowServer.textSize(string: string, fontInfo: fontInfo)
            return .sizeAndAscent(details.size, details.ascent)

        case .busy(let drawableId, let delay):
            windowServer.busy(drawableId: drawableId, delay: delay)
            return .nothing

        case .giprint(let drawableId):
            windowServer.infoPrint(drawableId: drawableId)
            return .nothing

        case .setwin(let drawableId, let pos, let size):
            windowServer.setWin(drawableId: drawableId, position: pos, size: size)
            return .nothing

        case .sprite(let id, let sprite):
            windowServer.setSprite(id: id, sprite: sprite)
            return .nothing

        case .clock(let drawableId, let clockInfo):
            windowServer.clock(drawableId: drawableId, info: clockInfo)
            return .nothing
    
        }
    }

    private func handleTouch(_ touch: UITouch, in view: CanvasView, with event: UIEvent, type: Async.PenEventType) {
        let location = touch.location(in: view)
        let screenLocation = touch.location(in: view.superview)
        sendEvent(.penevent(.init(timestamp: event.timestamp,
                                  windowId: view.id,
                                  type: type,
                                  modifiers: 0,
                                  x: Int(location.x),
                                  y: Int(location.y),
                                  screenx: Int(screenLocation.x),
                                  screeny: Int(screenLocation.y))))
    }

}

extension Program: InterpreterThreadDelegate {

    func interpreter(_ interpreter: InterpreterThread, pathForUrl url: URL) -> String? {
        return fileSystem.guestPath(for: url)
    }

    func interpreter(_ interpreter: InterpreterThread, didFinishWithResult result: OpoInterpreter.Result) {
        DispatchQueue.main.async {
            self.windowServer.shutdown()
            switch result {
            case .none:
                self.console.append("\n---Completed---")
            case .error(let err):
                self.console.append("\n---Error occurred:---\n\(err.description)")
            }
            self._state = .finished
            self.delegate?.program(self, didFinishWithResult: result)
        }
    }

}

extension Program: OpoIoHandler {

    func printValue(_ val: String) {
        DispatchQueue.main.sync {
            console.append(val)
        }
    }

    func readLine(escapeShouldErrorEmptyInput: Bool) -> String? {
        return delegate!.readLine(escapeShouldErrorEmptyInput: escapeShouldErrorEmptyInput)
    }

    func alert(lines: [String], buttons: [String]) -> Int {
        return delegate!.program(self, showAlertWithLines: lines, buttons: buttons)
    }

    func beep(frequency: Double, duration: Double) {
        do {
            try Sound.beep(frequency: frequency * 1000, duration: duration)
        } catch {
            delegate?.program(self, didEncounterError: error)
        }
    }

    func dialog(_ d: Dialog) -> Dialog.Result {
        return delegate!.dialog(d)
    }

    func menu(_ m: Menu.Bar) -> Menu.Result {
        return delegate!.menu(m)
    }

    func draw(operations: [Graphics.DrawCommand]) {
        return DispatchQueue.main.sync {
            return windowServer.draw(operations: operations)
        }
    }

    func graphicsop(_ operation: Graphics.Operation) -> Graphics.Result {
        return DispatchQueue.main.sync {
            return performGraphicsOperation(operation)
        }
    }

    func getScreenInfo() -> (Graphics.Size, Graphics.Bitmap.Mode) {
        return (device.screenSize, device.screenMode)
    }

    func fsop(_ op: Fs.Operation) -> Fs.Result {
        return fileSystem.perform(op)
    }

    func asyncRequest(_ request: Async.Request) {
        let req: Scheduler.Request
        switch request.type {
        case .getevent:
            req = GetEventRequest(handle: request.handle, program: self)
        case .after(let interval):
            req = TimerRequest(handle: request.handle, after: interval)
        case .at(let date):
            req = TimerRequest(handle: request.handle, at: date)
        case .playsound(let data):
            req = PlaySoundRequest(handle: request.handle, data: data)
        }
        scheduler.addPendingRequest(req)
    }

    func cancelRequest(_ requestHandle: Async.RequestHandle) {
        scheduler.cancelRequest(requestHandle)
    }

    func waitForAnyRequest() -> Async.Response {
        return scheduler.waitForAnyRequest()
    }

    func anyRequest() -> Async.Response? {
        return scheduler.anyRequest()
    }

    func testEvent() -> Bool {
        return !eventQueue.isEmpty()
    }

    func key() -> OplKeyCode? {
        let responseValue = eventQueue.first { responseValue in
            if case .keypressevent(_) = responseValue {
                return true
            }
            return false
        }
        guard case .keypressevent(let event) = responseValue else {
            return nil
        }
        return event.keycode
    }

    func setConfig(key: ConfigName, value: String) {
        print("setConfig \(key.rawValue) \(value)")
        oplConfig[key] = value
        switch key {
        case .clockFormat:
            let digital = value == "1"
            DispatchQueue.main.sync {
                windowServer.systemClockFormatChanged(newValue: digital)
            }
        }
    }

    func getConfig(key: ConfigName) -> String {
        return oplConfig[key]!
    }

    func setAppTitle(_ title: String) {
        DispatchQueue.main.sync {
            self.title = title
            delegate?.program(self, didUpdateTitle: title)
        }
    }

    func displayTaskList() {
        // TODO
    }
    func setForeground() {
        // TODO
    }

    func setBackground() {
        // TODO
    }
}

extension Program: WindowServerDelegate {

    func canvasView(_ canvasView: CanvasView, touchBegan touch: UITouch, with event: UIEvent) {
        handleTouch(touch, in: canvasView, with: event, type: .down)
    }

    func canvasView(_ canvasView: CanvasView, touchMoved touch: UITouch, with event: UIEvent) {
        handleTouch(touch, in: canvasView, with: event, type: .drag)
    }

    func canvasView(_ canvasView: CanvasView, touchEnded touch: UITouch, with event: UIEvent) {
        handleTouch(touch, in: canvasView, with: event, type: .up)
    }

    func canvasView(_ canvasView: CanvasView, insertCharacter character: Character) {
        print("insertCharacter: '\(character)'")
        guard let keyCode = OplKeyCode.from(string: String(character)) else {
            print("Ignoring unmapped character '\(character)'...")
            return
        }
        sendKey(keyCode)
    }

    func canvasViewDeleteBackward(_ canvasView: CanvasView) {
        sendKey(.backspace)
    }

}
