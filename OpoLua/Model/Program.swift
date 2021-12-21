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
    func printValue(_ val: String) -> Void
    func readLine(escapeShouldErrorEmptyInput: Bool) -> String?
    func alert(lines: [String], buttons: [String]) -> Int
    func dialog(_ d: Dialog) -> Dialog.Result
    func menu(_ m: Menu.Bar) -> Menu.Result
    func draw(operations: [Graphics.DrawCommand])
    func graphicsop(_ operation: Graphics.Operation) -> Graphics.Result

}

class Program {

    enum State {
        case idle
        case running
        case finished
    }

    private let object: OPLObject
    private let procedureName: String?
    private let device: Device
    private let thread: InterpreterThread
    private let eventQueue = ConcurrentQueue<Async.ResponseValue>()
    private let scheduler = Scheduler()

    private var state: State = .idle

    weak var delegate: ProgramDelegate?

    var name: String {
        if let procedureName = procedureName {
            return [object.name, procedureName].joined(separator: "\\")
        } else {
            return object.name
        }
    }

    var screenSize: Graphics.Size {
        return device.screenSize
    }

    init(object: OPLObject, procedureName: String? = nil, device: Device = .series5) {
        self.object = object
        self.procedureName = procedureName
        self.device = device
        self.thread = InterpreterThread(object: object, procedureName: procedureName)
        self.thread.delegate = self
        self.thread.handler = self

        scheduler.addHandler(.getevent) { request in
            request.complete(self.eventQueue.takeFirst())
        }
        scheduler.addHandler(.playsound) { request in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                request.complete(.completed)
            }
        }
        scheduler.addHandler(.sleep) { request in
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(request.request.intVal!) / 1000.0)) {
                request.complete(.completed)
            }
        }
    }

    func start() {
        guard state == .idle else {
            return
        }
        state = .running
        thread.start()
    }

    func sendMenu() {
        sendKeyPress(.menu)
    }

    func sendKeyPress(_ key: OplKeyCode) {
        let timestamp = Int(NSDate().timeIntervalSince1970)
        let modifiers = Modifiers()
        sendEvent(.keydownevent(.init(timestamp: timestamp, keycode: key, modifiers: modifiers)))
        sendEvent(.keypressevent(.init(timestamp: timestamp, keycode: key, modifiers: modifiers, isRepeat: false)))
        sendEvent(.keyupevent(.init(timestamp: timestamp, keycode: key, modifiers: modifiers)))
    }

    func sendEvent(_ event: Async.ResponseValue) {
        eventQueue.append(event)
    }

    private func findCorrectCase(in path: URL, for uncasedName: String) -> String {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: []) else {
            return uncasedName
        }
        let uppercasedName = uncasedName.uppercased()
        for url in contents {
            let name = url.lastPathComponent
            if name.uppercased() == uppercasedName {
                return name
            }
        }
        return uncasedName
    }

    private func mapToNative(path: String) -> URL? {
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
                // Have to do some nasty hacks here to appear case-insensitive
                let name = findCorrectCase(in: result, for: String(component))
                result.appendPathComponent(name)
            }
            return result.absoluteURL
        } else {
            return nil
        }
    }

    
}

extension Program: InterpreterThreadDelegate {

    func interpreter(_ interpreter: InterpreterThread, didFinishWithResult result: OpoInterpreter.Result) {
        // TODO: Should this be a dispatch?
        DispatchQueue.main.async {
            self.state = .finished
            self.delegate?.program(self, didFinishWithResult: result)
        }
    }

}

extension Program: OpoIoHandler {

    func printValue(_ val: String) {
        delegate!.printValue(val)
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
