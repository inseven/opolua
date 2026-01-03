// Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe
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

import Foundation
import Combine

import OpoLuaCore

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
    func program(_ program: Program, didSetCursorPosition cursorPosition: CGPoint?)

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

    var title: String  // main
    var icon: Icon  // main  TODO: let?

    var rootView: RootView {
        return windowServer.rootView
    }

    var uid3: UID? {
        return applicationMetadata?.uid3
    }

    var metadata: Metadata {
        guard let systemFileSystem = fileSystem as? SystemFileSystem else {
            return Metadata()
        }
        return systemFileSystem.metadata
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
            case .locale:
                oplConfig[key] = "en_GB"
            }
        }
        
        switch configuration.device {
        case .psionSeries3, .psionSeries3c, .psionSiena:
            break
        case .psionSeries5, .geofoxOne:
            let romfs = Bundle.main.resourceURL!.appendingPathComponent("z-s5", isDirectory: true)
            self.fileSystem.set(sharedDrive: "Z", url: romfs, readonly: true)
        case .psionRevo:
            let romfs = Bundle.main.resourceURL!.appendingPathComponent("z-revo", isDirectory: true)
            self.fileSystem.set(sharedDrive: "Z", url: romfs, readonly: true)
        case .psionSeries7:
            let romfs = Bundle.main.resourceURL!.appendingPathComponent("z-s7", isDirectory: true)
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

#if canImport(UIKit)
    func toggleOnScreenKeyboard() {
        dispatchPrecondition(condition: .onQueue(.main))
        if windowServer.rootView.isFirstResponder {
            windowServer.rootView.resignFirstResponder()
        } else {
            windowServer.rootView.becomeFirstResponder()
        }
    }
#endif

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
        switch event {
        case .keydownevent(let keydown):
            currentKeys.insert(keydown.keycode)
            if configuration.device.isSibo {
            // SIBO doesn't do up or down events
                return
            }
        case .keyupevent(let keyup):
            currentKeys.remove(keyup.keycode)
            if configuration.device.isSibo {
            // SIBO doesn't do up or down events
                return
            }
        default:
            break
        }

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

        case .loadFont(let drawableId, let fontUid):
            if let metrics = windowServer.load(font: fontUid, into: drawableId) {
                return .fontMetrics(metrics)
            } else {
                return .error(.invalidArguments)
            }
        case .close(let drawableId):
            windowServer.close(drawableId: drawableId)
            return .nothing

        case .order(let drawableId, let position):
            windowServer.order(drawableId: drawableId, position: position)
            return .nothing

        case .rank(let drawableId):
            if let rank = windowServer.getWindowRank(for: drawableId) {
                return .rank(rank)
            } else {
                return .error(.invalidWindow)
            }

        case .show(let drawableId, let flag):
            windowServer.setVisiblity(handle: drawableId, visible: flag)
            return .nothing

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
            return .data(data)

        case .getimg(let drawableId, let rect):
            return .data(windowServer.getImageData(drawableId: drawableId, rect: rect))

        case .cursor(let cursor):
            windowServer.cursor(cursor)
            return .nothing
        }
    }
}

extension Program: InterpreterThreadDelegate {

    func interpreter(_ interpreter: InterpreterThread, pathForUrl url: URL) -> String? {
        return fileSystem.guestPath(for: url)
    }

    // TODO: Result might be better as an actual result. Oh. That's a Tom Thing.
    // TODO: Unclear to me whether this would be the right place to handle the error or not.
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
        if let textFieldInfo = info {
            delegate?.program(self,
                              didSetCursorPosition: CGPoint(x: CGFloat(textFieldInfo.cursorRect.midX),
                                                            y: CGFloat(textFieldInfo.cursorRect.midY)))
            DispatchQueue.main.sync {
                _ = windowServer.rootView.becomeFirstResponder()
            }
        } else {
            delegate?.program(self, didSetCursorPosition: nil)
            DispatchQueue.main.sync {
                _ = windowServer.rootView.resignFirstResponder()
            }
        }
    }

    func draw(operations: [Graphics.DrawCommand]) -> Graphics.Error? {
        return DispatchQueue.main.sync {
            return windowServer.draw(operations: operations)
        }
    }

    func graphicsop(_ operation: Graphics.Operation) -> Graphics.Result {
        return DispatchQueue.main.sync {
            return performGraphicsOperation(operation)
        }
    }

    func getDeviceInfo() -> (Graphics.Size, Graphics.Bitmap.Mode, String) {
        let device = configuration.device
        return (device.screenSize, device.screenMode, device.identifier)
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
            case .locale:
                break // TODO persist this? It's not currently settable, so...
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

    func canvasView(_ canvasView: CanvasView, penEvent: Async.PenEvent) {
        if penEvent.type == .pointerDown {
            sendEvent(.pendownevent(.init(timestamp: penEvent.timestamp, windowId: penEvent.windowId)))
        }
        sendEvent(.penevent(penEvent))
        // .penupevent is only sent when the pen is dragged into non-screen area
        // (ie the softkeys) which we don't have, so we basically never need to send it
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
