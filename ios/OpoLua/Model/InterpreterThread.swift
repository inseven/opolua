// Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe
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

import OpoLuaCore

protocol InterpreterThreadDelegate: AnyObject {

    func interpreter(_ interpreter: InterpreterThread, pathForUrl url: URL) -> String?
    func interpreter(_ interpreter: InterpreterThread, didFinishWithResult result: Error?)

}

class InterpreterThread: Thread {

    private let url: URL
    private let interpreter = OpoInterpreter()

    weak var delegate: InterpreterThreadDelegate?

    var handler: OpoIoHandler? {
        get {
            return interpreter.iohandler
        }
        set {
            interpreter.iohandler = newValue ?? DummyIoHandler()
        }
    }

    init(url: URL) {
        self.url = url
        super.init()
    }

    override func main() {
        let oplPath = delegate!.interpreter(self, pathForUrl: url)!
        do {
            try interpreter.run(devicePath: oplPath)
            delegate?.interpreter(self, didFinishWithResult: nil)
        } catch {
            delegate?.interpreter(self, didFinishWithResult: error)
        }
    }

    func interrupt() {
        interpreter.interrupt()
    }
}
