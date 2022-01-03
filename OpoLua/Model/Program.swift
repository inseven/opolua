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

protocol ProgramDelegate: AnyObject {

    func program(_ program: Program, didFinishWithResult result: OpoInterpreter.Result)
    func program(_ program: Program, didEncounterError error: Error)

    // TODO: These are directly copied from OpoIoHandler and should be thinned over time.
    func readLine(escapeShouldErrorEmptyInput: Bool) -> String?
    func alert(lines: [String], buttons: [String]) -> Int
    func dialog(_ d: Dialog) -> Dialog.Result
    func menu(_ m: Menu.Bar) -> Menu.Result
    func draw(operations: [Graphics.DrawCommand])
    func graphicsop(_ operation: Graphics.Operation) -> Graphics.Result

}

class Program {

    class Configuration {

        let url: URL
        let fileSystem: FileSystem

        var name: String {
            return url.name
        }

        var procedures: [OpoInterpreter.Procedure] {
            return OpoInterpreter.shared.getProcedures(file: url.path) ?? []
        }

        init(url: URL, fileSystem: FileSystem) {
            self.url = url
            self.fileSystem = fileSystem
        }

    }

    enum State {
        case idle
        case running
        case finished
    }

    class GetEventRequest: Scheduler.RequestBase {
        weak var program: Program?

        init(requestHandle: Int32, program: Program) {
            self.program = program
            super.init(requestHandle: requestHandle)
        }

        override func cancel() {
            if let prog = program {
                prog.geteventRequest = nil
            }
        }

        override func start() {
            guard let scheduler = self.scheduler, let program = self.program else {
                print("Cannot start request if scheduler or program isn't set!")
                return
            }
            scheduler.withLockHeld {
                precondition(program.geteventRequest == nil, "There can only be one geteventRequest!")
                program.geteventRequest = self
            }
        }
    }

    private let configuration: Configuration
    private let procedureName: String?
    private let device: Device
    private let thread: InterpreterThread
    private let eventQueue = ConcurrentQueue<Async.ResponseValue>()
    private let scheduler = Scheduler()
    fileprivate var geteventRequest: GetEventRequest?

    private var _state: State = .idle

    public var state: State {
        return _state
    }

    weak var delegate: ProgramDelegate?

    var console = Console()

    var name: String {
        if let procedureName = procedureName {
            return [configuration.name, procedureName].joined(separator: "\\")
        } else {
            return configuration.name
        }
    }

    var screenSize: Graphics.Size {
        return device.screenSize
    }

    init(configuration: Configuration, procedureName: String? = nil, device: Device = .psionSeries5) {
        self.configuration = configuration
        self.procedureName = procedureName
        self.device = device
        self.thread = InterpreterThread(object: configuration, procedureName: procedureName)
        self.thread.delegate = self
        self.thread.handler = self
    }

    func start() {
        guard state == .idle else {
            return
        }
        _state = .running
        thread.start()
    }

    func sendMenu() {
        sendKey(.menu)
    }

    func sendKeyDown(_ key: OplKeyCode) {
        sendEvent(.keydownevent(.init(timestamp: Int(NSDate().timeIntervalSince1970),
                                      keycode: key,
                                      modifiers: Modifiers())))
    }

    func sendKeyUp(_ key: OplKeyCode) {
        sendEvent(.keyupevent(.init(timestamp: Int(NSDate().timeIntervalSince1970),
                                    keycode: key,
                                    modifiers: Modifiers())))
    }

    func sendKeyPress(_ key: OplKeyCode) {
        sendEvent(.keypressevent(.init(timestamp: Int(NSDate().timeIntervalSince1970),
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
        var req: GetEventRequest?
        scheduler.withLockHeld {
            req = geteventRequest
            geteventRequest = nil
        }
        if let req = req {
            assert(eventQueue.isEmpty(), "Queue must be empty if there's a geteventRequest!")
            scheduler.complete(request: req, response: event)
        } else {
            eventQueue.append(event)
        }
    }

    private func mapToNative(path: String) -> URL? {
        return configuration.fileSystem.hostUrl(for: path)
    }

    private func handleTouch(_ touch: UITouch, in view: CanvasView, with event: UIEvent, type: Async.PenEventType) {
        let location = touch.location(in: view)
        let screenLocation = touch.location(in: view.superview)
        sendEvent(.penevent(.init(timestamp: Int(event.timestamp),
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
        return configuration.fileSystem.guestPath(for: url)
    }

    func interpreter(_ interpreter: InterpreterThread, didFinishWithResult result: OpoInterpreter.Result) {
        DispatchQueue.main.async {
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
        return delegate!.alert(lines: lines, buttons: buttons)
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
        return delegate!.draw(operations: operations)
    }

    func graphicsop(_ operation: Graphics.Operation) -> Graphics.Result {
        return delegate!.graphicsop(operation)
    }

    func getScreenSize() -> Graphics.Size {
        return device.screenSize
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
        case .isdir:
            let exists = fm.directoryExists(atPath: path)
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
        case .dir:
            if let names = try? fm.contentsOfDirectory(atPath: path) {
                var paths: [String] = []
                for name in names {
                    paths.append(op.path + name)
                }
                return .strings(paths)
            }
        }
        return .err(.notReady)
    }

    func asyncRequest(_ request: Async.Request) {
        switch request.type {
        case .getevent:
            let req = GetEventRequest(requestHandle: request.requestHandle, program: self)
            scheduler.addPendingRequest(req)
            if let event = eventQueue.first() {
                scheduler.complete(request: req, response: event)
            } else {
                req.start()
            }
        case .sleep:
            let req = Scheduler.TimerRequest(request: request)
            scheduler.addPendingRequest(req)
            req.start()
        case .playsound:
            // TODO
            let req = Scheduler.TimerRequest(requestHandle: request.requestHandle, interval: 0.1)
            scheduler.addPendingRequest(req)
            req.start()
        }
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

}

extension Program: CanvasViewDelegate {

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
