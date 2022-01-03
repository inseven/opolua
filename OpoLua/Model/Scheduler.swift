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
import Combine

class Scheduler {

    /// Base class for all asynchronous tasks managed by the Scheduler.
    class RequestBase {
        let requestHandle: Int32
        fileprivate(set) weak var scheduler: Scheduler?
        fileprivate var response: Async.ResponseValue?

        init(requestHandle: Int32) {
            self.requestHandle = requestHandle
            response = nil
        }

        /// Perform any cancellation needed by this request. Called with the
        /// scheduler lock held therefore must not result in any calls back into
        /// the scheduler. Must be overridden by subclasses.
        func cancel() {
            fatalError("RequestBase.cancel() must be overridden!")
        }

        /// Start the thing that will result in the complete call occurring.
        func start() {
            fatalError("RequestBase.start() must be overridden!")
        }            
    }

    class CancellableRequest: RequestBase {
        var cancellable: Cancellable?

        override func cancel() {
            cancellable?.cancel()
        }
    }

    /// A one-shot interval-based timer.
    class TimerRequest: CancellableRequest {
        let interval: Double
        init(requestHandle: Int32, interval: Double) {
            self.interval = interval
            super.init(requestHandle: requestHandle)
        }

        convenience init(request: Async.Request) {
            precondition(request.type == .sleep && request.intVal != nil)
            let intervalSeconds = Double(request.intVal!) / 1000.0
            self.init(requestHandle: request.requestHandle, interval: intervalSeconds)
        }

        override func start() {
            self.cancellable = DispatchQueue.main.schedule(after: .init(.now() + interval),
                    interval: .init(integerLiteral: 1),
                    tolerance: .init(floatLiteral: 0.001),
                    options: nil) {
                self.cancellable?.cancel() // Stop the timer firing again
                self.cancellable = nil
                self.scheduler?.complete(request: self, response: .completed)
            }
        }
    }

    var requests: [RequestBase] = []
    var lock = NSCondition()

    func withLockHeld(run code: () -> Void) {
        lock.lock()
        code()
        lock.unlock()
    }

    func addPendingRequest(_ request: RequestBase) {
        precondition(request.scheduler == nil, "Request has already been added to a scheduler?")
        withLockHeld {
            request.scheduler = self
            requests.append(request)
        }
    }

    func complete(request: RequestBase, response: Async.ResponseValue) {
        withLockHeld {
            completeLocked(request: request, response: response)
        }
    }

    private func completeLocked(request: RequestBase, response: Async.ResponseValue) {
        precondition(request.response == nil, "Cannot complete a request that already has a response set!")
        request.response = response
        lock.broadcast()
    }

    func cancelRequest(_ requestHandle: Int32) {
        // Note, it's not an error if the request has already been completed or
        // even already gone from requests.
        lock.lock()
        if let req = requests.first(where: { $0.requestHandle == requestHandle }) {
            if req.response == nil {
                req.cancel()
                completeLocked(request: req, response: .cancelled)
            }
            lock.unlock()
            return
        }
        lock.unlock()
    }

    private func removeCompletedRequest() -> Async.Response? {
        // lock must be held
        if let idx = requests.firstIndex(where: { $0.response != nil }) {
            let req = requests.remove(at: idx)
            req.scheduler = nil
            let response = Async.Response(requestHandle: req.requestHandle, value: req.response!)
            return response
        } else {
            return nil
        }
    }

    func waitForAnyRequest() -> Async.Response {
        lock.lock()
        defer {
            lock.unlock()
        }
        repeat {
            if let response = removeCompletedRequest() {
                return response
            }
            lock.wait()
        } while true
    }

    func anyRequest() -> Async.Response? {
        lock.lock()
        defer {
            lock.unlock()
        }
        if let response = removeCompletedRequest() {
            return response
        }
        return nil
    }

}
