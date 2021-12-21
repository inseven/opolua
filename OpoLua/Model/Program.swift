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

import Foundation

protocol ProgramDelegate: AnyObject {

    func program(program: Program, didFinishWithResult result: OpoInterpreter.Result)
    func program(program: Program, didEncounterError error: Error)

    // TODO: These are directly copied from OpoIoHandler and should be thinned over time.
    func printValue(_ val: String) -> Void
    func readLine(escapeShouldErrorEmptyInput: Bool) -> String?
    func alert(lines: [String], buttons: [String]) -> Int
    func dialog(_ d: Dialog) -> Dialog.Result
    func menu(_ m: Menu.Bar) -> Menu.Result
    func draw(operations: [Graphics.DrawCommand])
    func graphicsop(_ operation: Graphics.Operation) -> Graphics.Result
    func getScreenSize() -> Graphics.Size
    func asyncRequest(_ request: Async.Request)
    func cancelRequest( _ requestHandle: Int32)
    func waitForAnyRequest() -> Async.Response
    func anyRequest() -> Async.Response?
    func testEvent() -> Bool
    func key() -> OplKeyCode?

}

class Program {

    enum State {
        case idle
        case running
    }

    var object: OPLObject
    var procedureName: String?

    let opo = OpoInterpreter()
    let runtimeQueue = DispatchQueue(label: "ScreenViewController.runtimeQueue")

    var state: State = .idle

    weak var delegate: ProgramDelegate?

    var name: String {
        if let procedureName = procedureName {
            return [object.name, procedureName].joined(separator: "\\")
        } else {
            return object.name
        }
    }

    init(object: OPLObject, procedureName: String? = nil) {
        self.object = object
        self.procedureName = procedureName
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
            // TODO: Maybe don't dispatch this?
            DispatchQueue.main.async {
                self.delegate?.program(program: self, didFinishWithResult: result)
            }
        }
    }

    func findCorrectCase(in path: URL, for uncasedName: String) -> String {
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
            delegate?.program(program: self, didEncounterError: error)
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
        return delegate!.getScreenSize()
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
        delegate!.asyncRequest(request)
    }

    func cancelRequest(_ requestHandle: Int32) {
        delegate!.cancelRequest(requestHandle)
    }

    func waitForAnyRequest() -> Async.Response {
        return delegate!.waitForAnyRequest()
    }

    func anyRequest() -> Async.Response? {
        return delegate!.anyRequest()
    }

    func testEvent() -> Bool {
        return delegate!.testEvent()
    }

    func key() -> OplKeyCode? {
        return delegate!.key()
    }


}
