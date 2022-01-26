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
                try FileManager.default.createDirectory(at: destinationUrl.appendingPathComponent("c"), withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: destinationUrl.appendingPathComponent("d"), withIntermediateDirectories: true)
                let result = self.interpreter.installSisFile(path: self.url.path)
                self.delegate?.installer(self, didFinishWithResult: result)
            } catch {
                // TODO: Clean up if we've failed to install the file.
                self.delegate?.installer(self, didFailWithError: error)
            }
        }
    }

}

extension Installer: OpoIoHandler {

    func printValue(_ val: String) {}
    func readLine(initialValue: String, allowCancel: Bool) -> String? { return nil }
    func alert(lines: [String], buttons: [String]) -> Int { return 0 }
    func beep(frequency: Double, duration: Double) {}
    func draw(operations: [Graphics.DrawCommand]) {}
    func graphicsop(_ operation: Graphics.Operation) -> Graphics.Result { return .nothing }
    func getScreenInfo() -> (Graphics.Size, Graphics.Bitmap.Mode) { return (.zero, .gray2) }

    func fsop(_ op: Fs.Operation) -> Fs.Result {
        return fileSystem.perform(op)
    }

    func asyncRequest(_ request: Async.Request) {}
    func cancelRequest(_ requestHandle: Async.RequestHandle) {}
    func waitForAnyRequest() -> Async.Response { return .init(handle: 0, value: .cancelled) }
    func anyRequest() -> Async.Response? { return nil }
    func testEvent() -> Bool { return false }
    func key() -> OplKeyCode? { return nil }
    func setConfig(key: ConfigName, value: String) {}
    func getConfig(key: ConfigName) -> String { return "" }
    func setAppTitle(_ title: String) {}
    func displayTaskList() {}
    func setForeground() {}
    func setBackground() {}
}
