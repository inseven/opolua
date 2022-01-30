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

import Combine
import UIKit
import GameController

/**
 Called on the main queue.
 */
protocol ProgramLifecycleObserver: NSObject {

    func program(_ program: Program, didFinishWithResult result: OpoInterpreter.Result)
    func program(_ program: Program, didEncounterError error: Error)
    func program(_ program: Program, didUpdateTitle title: String)

}

/**
 Called on the program's runtime queue.
 */
protocol ProgramDelegate: AnyObject {

    func program(_ program: Program, editText params: EditParams) -> String?
    func programDidRequestBackground(_ program: Program)
    func programDidRequestTaskList(_ program: Program)

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

    private let settings: Settings
    let url: URL
    private let configuration: Configuration
    private let thread: InterpreterThread
    private let appInfo: OpoInterpreter.AppInfo?
    private let eventQueue = ConcurrentQueue<Async.ResponseValue>()
    let windowServer: WindowServer
    private let scheduler = Scheduler()
    private var geteventRequest: GetEventRequest?
    private var settingsSink: AnyCancellable?

    private var _state: State = .idle

    private var oplConfig: [ConfigName: String] = [:]

    public var state: State {
        return _state
    }

    private var observers: [ProgramLifecycleObserver] = []
    weak var delegate: ProgramDelegate?

    var console = Console()

    var title: String
    var icon: Icon

    var rootView: UIView {
        return windowServer.rootView
    }

    var uid3: UID? {
        return appInfo?.uid3
    }

    lazy private var fileSystem: FileSystem = {
        do {
            return try FileManager.default.detectSystemFileSystem(for: url) ?? ObjectFileSystem(objectUrl: url)
        } catch {
            return ObjectFileSystem(objectUrl: url)
        }
    }()

    init(settings: Settings, url: URL) {
        self.settings = settings
        self.url = url
        self.configuration = Configuration.load(for: url)
        self.thread = InterpreterThread(url: url)
        let appInfo = Directory.appInfo(forApplicationUrl: url, interpreter: OpoInterpreter())
        self.appInfo = appInfo
        self.title = appInfo?.caption ?? url.name
        self.icon = appInfo?.icon() ?? (url.pathExtension.lowercased() == "opo" ? .opo : .unknownApplication) // TODO: This should be an OPO icon if it's an OPO file.
        self.windowServer = WindowServer(device: configuration.device, screenSize: configuration.device.screenSize)
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

    func addObserver(_ observer: ProgramLifecycleObserver) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.observers.append(observer)
    }

    func removeObserver(_ observer: ProgramLifecycleObserver) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.observers.removeAll { $0.isEqual(observer) }
    }

    func resume() {
        guard state == .idle else {
            sendForegroundEvent()
            return
        }
        _state = .running
        if let uid3 = uid3 {
            print("Starting program with UID3 \(uid3.description)")
        }
        settingsSink = settings.objectWillChange.sink { [weak self] _ in
            guard let self = self else {
                return
            }
            dispatchPrecondition(condition: .onQueue(.main))
            self.oplConfig[.clockFormat] = self.settings.clockType == .analog ? "0" : "1"
            self.windowServer.systemClockFormatChanged(isDigital: self.settings.clockType == .digital)
        }
        oplConfig[.clockFormat] = settings.clockType == .analog ? "0" : "1"
        thread.start()
    }

    func suspend() {
        sendBackgroundEvent()
    }

    func toggleOnScreenKeyboard() {
        if windowServer.rootView.isFirstResponder {
            windowServer.rootView.resignFirstResponder()
        } else {
            windowServer.rootView.becomeFirstResponder()
        }
    }

    func sendQuit() {
        sendEvent(.quitevent)
    }

    func forceQuit() {

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else {
                return
            }
            self.sendKeyUp(key)
        }
    }

    func sendEvent(_ event: Async.ResponseValue) {
        eventQueue.append(event)
        checkGetEventCompletion()
    }

    private func sendForegroundEvent() {
        sendEvent(.foregrounded(.init(timestamp: ProcessInfo.processInfo.systemUptime)))
    }

    private func sendBackgroundEvent() {
        sendEvent(.backgrounded(.init(timestamp: ProcessInfo.processInfo.systemUptime)))
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
            let metrics = WindowServer.textSize(string: string, fontInfo: fontInfo)
            return .textMetrics(metrics)

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

        case .peekline(let drawableId, let position, let numPixels, let mode):
            let data = windowServer.peekLine(drawableId: drawableId, position: position, numPixels: numPixels, mode: mode)
            return .peekedData(data)

        }
    }

    private func handleTouch(_ touch: UITouch, in view: CanvasView, with event: UIEvent, type: Async.PenEventType) {
        var location = touch.location(in: view)
        let screenView = windowServer.rootView
        var screenLocation = touch.location(in: screenView)

        // Is there a better way of doing this?
        let screenSize = screenView.bounds.size
        var xdelta = 0.0
        var ydelta = 0.0
        if screenLocation.x < 0 {
            xdelta = -screenLocation.x
        } else if screenLocation.x > screenSize.width {
            xdelta = screenSize.width - screenLocation.x
        }
        if screenLocation.y < 0 {
            ydelta = -screenLocation.y
        } else if screenLocation.y > screenSize.height {
            ydelta = screenSize.height - screenLocation.y
        }
        location = location.move(x: xdelta, y: ydelta)
        screenLocation = screenLocation.move(x: xdelta, y: ydelta)

        if type == .down {
            sendEvent(.pendownevent(.init(timestamp: event.timestamp, windowId: view.id)))
        }
        sendEvent(.penevent(.init(timestamp: event.timestamp,
                                  windowId: view.id,
                                  type: type,
                                  modifiers: event.modifierFlags.oplModifiers(),
                                  x: Int(location.x),
                                  y: Int(location.y),
                                  screenx: Int(screenLocation.x),
                                  screeny: Int(screenLocation.y))))
        // .penupevent is only sent when the pen is dragged into non-screen area
        // (ie the softkeys) which we don't have, so we basically never need to send it
    }

}

extension Program: InterpreterThreadDelegate {

    func interpreter(_ interpreter: InterpreterThread, pathForUrl url: URL) -> String? {
        return fileSystem.guestPath(for: url)
    }

    func interpreter(_ interpreter: InterpreterThread, didFinishWithResult result: OpoInterpreter.Result) {
        DispatchQueue.main.sync {
            self.windowServer.shutdown()
            switch result {
            case .none:
                self.console.append("\n---Completed---")
            case .error(let err):
                self.console.append("\n---Error occurred:---\n\(err.description)")
            }
            self._state = .finished
            for observer in self.observers {
                observer.program(self, didFinishWithResult: result)
            }
        }
    }

}

extension Program: OpoIoHandler {

    func printValue(_ val: String) {
        DispatchQueue.main.sync {
            console.append(val)
        }
    }

    func editValue(_ params: EditParams) -> String? {
        return delegate!.program(self, editText: params)
    }

    func beep(frequency: Double, duration: Double) {
        do {
            try Sound.beep(frequency: frequency * 1000, duration: duration)
        } catch {
            DispatchQueue.main.sync {
                for observer in self.observers {
                    observer.program(self, didEncounterError: error)
                }
            }
        }
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
        return (configuration.device.screenSize, configuration.device.screenMode)
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

    func key() -> Async.KeyPressEvent? {
        let responseValue = eventQueue.first { responseValue in
            if case .keypressevent(_) = responseValue {
                return true
            }
            return false
        }
        guard case .keypressevent(let event) = responseValue else {
            return nil
        }
        return event
    }

    func setConfig(key: ConfigName, value: String) {
        DispatchQueue.main.sync {
            oplConfig[key] = value
            switch key {
            case .clockFormat:
                let clockType: Settings.ClockType = value == "1" ? .digital : .analog
                settings.clockType = clockType
            }
        }
    }

    func getConfig(key: ConfigName) -> String {
        return DispatchQueue.main.sync {
            return oplConfig[key]!
        }
    }

    func setAppTitle(_ title: String) {
        DispatchQueue.main.sync {
            self.title = title
            for observer in self.observers {
                observer.program(self, didUpdateTitle: title)
            }
        }
    }

    func displayTaskList() {
        delegate?.programDidRequestTaskList(self)
    }

    func setForeground() {
        // TODO
    }

    func setBackground() {
        self.delegate?.programDidRequestBackground(self)
    }

    func stop() {
        // This calls interpreter.interrupt() which sets a hook to force any exectuting Lua code to call error(KStopErr)
        thread.interrupt()
        // And this unblocks the interpreter thread if it was blocked in waitForAnyRequest()
        scheduler.interrupt()
    }
}

extension Program: WindowServerDelegate {

    func windowServerClockIsDigital(_ windowServer: WindowServer) -> Bool {
        return self.oplConfig[.clockFormat] == "1"
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

    func canvasView(_ canvasView: CanvasView, sendKey key: OplKeyCode) {
        sendKey(key)
    }

}
