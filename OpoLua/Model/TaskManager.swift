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

/**
 Called on the main queue.
 */
protocol TaskManagerObserver: NSObject {

    func taskManagerDidUpdate(_ taskManager: TaskManager)

}

/**
 Called on the main queue.
 */
protocol TaskManagerDelegate: AnyObject {

    func taskManagerShowTaskList(_ taskManager: TaskManager)
    func taskManager(_ taskManager: TaskManager, bringProgramToForeground program: Program)

}

class TaskManager: NSObject {

    private var programsByUrl: [URL: Program] = [:]
    private var observers: [TaskManagerObserver] = []

    weak var delegate: TaskManagerDelegate?

    var programs: [Program] {
        return Array(programsByUrl.values)
    }

    // TODO: Consider whether this should be responsible for restarting in a different mode?
    func program(for url: URL) -> Program {
        dispatchPrecondition(condition: .onQueue(.main))
        if let program = programsByUrl[url] {
            return program
        }
        // TODO: Lifecycle delegate.
        let program = Program(url: url)
        program.addObserver(self)
        programsByUrl[url] = program
        notifyObservers()
        return program
    }

    func isRunning(_ url: URL) -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        return programsByUrl[url] != nil
    }

    func showTaskList() {
        dispatchPrecondition(condition: .onQueue(.main))
        delegate?.taskManagerShowTaskList(self)
    }

    func foregroundProgram(_ program: Program) {
        dispatchPrecondition(condition: .onQueue(.main))
        delegate?.taskManager(self, bringProgramToForeground: program)
    }

    func quit(_ url: URL) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let program = programsByUrl[url] else {
            return
        }
        program.quit()
    }

    func addObserver(_ observer: TaskManagerObserver) {
        dispatchPrecondition(condition: .onQueue(.main))
        observers.append(observer)
    }

    func removeObserver(_ observer: TaskManagerObserver) {
        dispatchPrecondition(condition: .onQueue(.main))
        observers.removeAll { $0.isEqual(observer) }
    }

    private func notifyObservers() {
        dispatchPrecondition(condition: .onQueue(.main))
        for observer in observers {
            observer.taskManagerDidUpdate(self)
        }
    }

}

extension TaskManager: ProgramLifecycleObserver {

    func program(_ program: Program, didFinishWithResult result: OpoInterpreter.Result) {
        dispatchPrecondition(condition: .onQueue(.main))
        print("program did finish")
        programsByUrl.removeValue(forKey: program.url)
        notifyObservers()
    }

    func program(_ program: Program, didEncounterError error: Error) {
        dispatchPrecondition(condition: .onQueue(.main))
        print("program did encouter error")
        programsByUrl.removeValue(forKey: program.url)
        notifyObservers()
    }

    func program(_ program: Program, didUpdateTitle title: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        print("program did update title")
        notifyObservers()
    }

}
