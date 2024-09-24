// Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe
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

    func program(_ program: Program, didFinishWithResult result: Error?)
    func program(_ program: Program, didUpdateTitle title: String)

}

/**
 Called on the program's runtime queue.
 */
protocol ProgramDelegate: AnyObject {

    func programDidRequestBackground(_ program: Program)
    func programDidRequestTaskList(_ program: Program)
    func program(_ program: Program, runApplication applicationIdentifier: ApplicationIdentifier, url: URL) -> Int32?

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

    class KeyaRequest: Scheduler.Request {
        weak var program: Program?

        init(handle: Async.RequestHandle, program: Program) {
            self.program = program
            super.init(handle: handle)
        }

        override func cancel() {
            if let prog = program {
                prog.keyaRequest = nil
            }
        }

        override func start() {
            guard let program = self.program else {
                print("Cannot start request if program isn't set!")
                return
            }
            program.startKeyaRequest(self)
        }
    }

    private let settings: Settings
    let url: URL
    private let configuration: Configuration
    private let thread: InterpreterThread
    private let applicationMetadata: ApplicationMetadata?
    // eventQueue is only for things which can be returned from GETEVENT32
    private let eventQueue = ConcurrentQueue<Async.ResponseValue>()
    private var currentKeys = Set<OplKeyCode>()
    let windowServer: WindowServer
    private let scheduler = Scheduler()
    private var geteventRequest: GetEventRequest?
    private var keyaRequest: KeyaRequest?
    private var settingsSink: AnyCancellable?

    private var _state: State = .idle
    private static let kOpTime: TimeInterval = 3.5 / 1000000 // Make this bigger to slow the interpreter down
    private var lastOpTime = Date()

    private var oplConfig: [ConfigName: String] = [:]

    public var state: State {
        return _state
    }

    private var observers: [ProgramLifecycleObserver] = []
    weak var delegate: ProgramDelegate?

    var title: String
    var icon: Icon

    var rootView: UIView {
        return windowServer.rootView
    }

    var uid3: UID? {
        return applicationMetadata?.uid3
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
        let applicationMetadata = PsiLuaEnv().cachedAppInfo(forApplicationUrl: url)
        let defaultDevice = Device.getDefault(forEra: applicationMetadata?.appInfo.era)
        self.configuration = Configuration.load(for: url, defaultDevice: defaultDevice)
        self.thread = InterpreterThread(url: url)
        self.applicationMetadata = applicationMetadata
        self.title = applicationMetadata?.caption ?? url.localizedName
        self.icon = applicationMetadata?.cachedIcon() ?? (url.pathExtension.lowercased() == "opo" ? .opo() : .unknownApplication())
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
        if configuration.device != .psionSeries3c {
            let romfs = Bundle.main.resourceURL!.appendingPathComponent("z-s5", isDirectory: true)
            self.fileSystem.set(sharedDrive: "Z", url: romfs, readonly: true)
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
        switch event {
        case .keydownevent(let keydown):
            currentKeys.insert(keydown.keycode)
        case .keyupevent(let keyup):
            currentKeys.remove(keyup.keycode)
        default:
            break
        }
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
            precondition(self.keyaRequest == nil, "GetEvent request after Keya!")
            self.geteventRequest = request
        }
        checkGetEventCompletion()
    }

    func startKeyaRequest(_ request: KeyaRequest) {
        scheduler.withLockHeld {
            precondition(self.keyaRequest == nil, "Duplicate keyaRequest!")
            precondition(self.geteventRequest == nil, "Keya request after GetEvent!")
            self.keyaRequest = request
        }
        checkGetEventCompletion()
    }

    func checkGetEventCompletion() {
        scheduler.withLockHeld {
            if let request = self.geteventRequest,
               let event = eventQueue.tryTakeFirst() {
                self.geteventRequest = nil
                scheduler.completeLocked(request: request, response: event)
            } else if let request = self.keyaRequest {
                while true {
                    // The docs for KEYA state that any non key event gets dropped
                    // Note, only complete the event for keys with a charcode (ie not modifiers)
                    if let event = eventQueue.tryTakeFirst() {
                        if case .keypressevent(let k) = event, k.keycode.toCharcode() != nil {
                            self.keyaRequest = nil
                            scheduler.completeLocked(request: request, response: event)
                            break
                        }
                    } else {
                        break
                    }
                }
            }
        }
    }

    private func performGraphicsOperation(_ operation: Graphics.Operation) -> Graphics.Result {
        dispatchPrecondition(condition: .onQueue(.main))
        switch (operation) {

        case .createBitmap(let id, let size, let mode):
            windowServer.createBitmap(id: id, size: size, mode: mode)
            return .nothing

        case .createWindow(let id, let rect, let mode, let shadowSize):
            windowServer.createWindow(id: id, rect: rect, mode: mode, shadowSize: shadowSize)
            return .nothing

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

        case .sprite(let windowId, let id, let sprite):
            windowServer.setSprite(window: windowId, id: id, sprite: sprite)
            return .nothing

        case .clock(let drawableId, let clockInfo):
            windowServer.clock(drawableId: drawableId, info: clockInfo)
            return .nothing

        case .peekline(let drawableId, let position, let numPixels, let mode):
            let data = windowServer.peekLine(drawableId: drawableId, position: position, numPixels: numPixels, mode: mode)
            return .peekedData(data)

        case .cursor(let cursor):
            windowServer.cursor(cursor)
            return .nothing
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

    func screenshot() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: rootView.frame.size, format: format)
        let uiImage = renderer.image { rendererContext in
            let context = rendererContext.cgContext
            context.setAllowsAntialiasing(false)
            context.interpolationQuality = .none
            rootView.layer.render(in: context)
        }
        return uiImage
    }

}

extension Program: InterpreterThreadDelegate {

    func interpreter(_ interpreter: InterpreterThread, pathForUrl url: URL) -> String? {
        return fileSystem.guestPath(for: url)
    }

    func interpreter(_ interpreter: InterpreterThread, didFinishWithResult result: Error?) {
        DispatchQueue.main.sync {
            interpreter.handler = nil
            self.windowServer.shutdown()
            self._state = .finished
            for observer in self.observers {
                observer.program(self, didFinishWithResult: result)
            }
        }
    }

}

extension Program: OpoIoHandler {

    func printValue(_ val: String) {
        print(val)
    }

    func textEditor(_ info: TextFieldInfo?) {
        // print("textEditor: \(String(describing: info))")
    }

    func beep(frequency: Double, duration: Double) -> Error? {
        do {
            try Sound.beep(frequency: frequency * 1000, duration: duration)
            return nil
        } catch {
            return error
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

    func asyncRequest(handle: Async.RequestHandle, type: Async.RequestType) {
        let req: Scheduler.Request
        switch type {
        case .getevent:
            req = GetEventRequest(handle: handle, program: self)
        case .keya:
            req = KeyaRequest(handle: handle, program: self)
        case .after(let interval):
            req = TimerRequest(handle: handle, after: interval)
        case .at(let date):
            req = TimerRequest(handle: handle, at: date)
        case .playsound(let data):
            req = PlaySoundRequest(handle: handle, data: data)
        }
        scheduler.addPendingRequest(req)
    }

    func cancelRequest(handle: Async.RequestHandle) {
        scheduler.cancelRequest(handle)
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

    func keysDown() -> Set<OplKeyCode> {
        let result = DispatchQueue.main.sync {
            return currentKeys
        }
        return result
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

    func runApp(name: String, document: String) -> Int32? {
        guard let applicationIdentifier = ApplicationIdentifier(rawValue: name),
              let (url, _) = fileSystem.hostUrl(for: document)
        else {
            return nil
        }
        return delegate?.program(self, runApplication: applicationIdentifier, url: url)
    }

    func opsync() {
        Thread.sleep(until: lastOpTime.addingTimeInterval(Self.kOpTime))
        lastOpTime = Date()
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

    func windowServer(_ windowServer: WindowServer, insertCharacter character: Character) {
        guard let keyCode = OplKeyCode.from(string: String(character)) else {
            print("Ignoring unmapped character '\(character)'...")
            return
        }
        sendKey(keyCode)
    }

    func windowServerDeleteBackward(_ windowServer: WindowServer) {
        sendKey(.backspace)
    }

    func windowServer(_ windowServer: WindowServer, sendKey key: OplKeyCode) {
        sendKey(key)
    }

}
