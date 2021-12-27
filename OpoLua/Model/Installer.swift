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

protocol InstallerDelegate: AnyObject {

    func installer(_ installer: Installer, didFinishWithResult result: OpoInterpreter.Result)
    func installer(_ installer: Installer, didFailWithError error: Error)

}

class Installer {

    let url: URL
    let fileSystem: FileSystem
    let interpreter = OpoInterpreter()

    weak var delegate: InstallerDelegate?

    init(url: URL, fileSystem: FileSystem) {
        self.url = url
        self.fileSystem = fileSystem
        self.interpreter.iohandler = self
    }

    func run() {
        DispatchQueue.global().async {
            do {
                let destinationUrl = self.url.deletingPathExtension()
                print("Installing to \(destinationUrl)...")
                try FileManager.default.createDirectory(at: destinationUrl, withIntermediateDirectories: true)
                let result = self.interpreter.installSisFile(path: self.url.path)
                self.delegate?.installer(self, didFinishWithResult: result)
            } catch {
                self.delegate?.installer(self, didFailWithError: error)
            }
        }
    }

}

extension Installer: OpoIoHandler {

    func printValue(_ val: String) {}
    func readLine(escapeShouldErrorEmptyInput: Bool) -> String? { return nil }
    func alert(lines: [String], buttons: [String]) -> Int { return 0 }
    func beep(frequency: Double, duration: Double) {}
    func dialog(_ d: Dialog) -> Dialog.Result { return .none }
    func menu(_ m: Menu.Bar) -> Menu.Result { return .none }
    func draw(operations: [Graphics.DrawCommand]) {}
    func graphicsop(_ operation: Graphics.Operation) -> Graphics.Result { return .nothing }
    func getScreenSize() -> Graphics.Size { return .zero }

    func fsop(_ op: Fs.Operation) -> Fs.Result {
        print(op)
        return .err(.notReady)
    }

    func asyncRequest(_ request: Async.Request) {}
    func cancelRequest(_ requestHandle: Int32) {}
    func waitForAnyRequest() -> Async.Response { return .init(requestHandle: 0, value: .cancelled) }
    func anyRequest() -> Async.Response? { return nil }
    func testEvent() -> Bool { return false }
    func key() -> OplKeyCode? { return nil }
}