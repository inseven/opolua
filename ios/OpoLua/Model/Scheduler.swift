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
import Combine

import OpoLuaCore

class Scheduler {

    /// Base class for all asynchronous tasks managed by the Scheduler.
    // TODO: Make this a protocol.
    class Request {
        let handle: Async.RequestHandle
        fileprivate(set) weak var scheduler: Scheduler?
        fileprivate var response: Async.ResponseValue?

        init(handle: Async.RequestHandle) {
            self.handle = handle
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

    var requests: [Request] = []
    var lock = NSCondition()
    var interrupted = false

    func withLockHeld(run code: () -> Void) {
        lock.lock()
        code()
        lock.unlock()
    }

    func addPendingRequest(_ request: Request) {
        precondition(request.scheduler == nil, "Request has already been added to a scheduler?")
        withLockHeld {
            request.scheduler = self
            requests.append(request)
        }
        request.start()
    }

    func complete(request: Request, response: Async.ResponseValue) {
        withLockHeld {
            completeLocked(request: request, response: response)
        }
    }

    func completeLocked(request: Request, response: Async.ResponseValue) {
        precondition(request.response == nil, "Cannot complete a request that already has a response set!")
        request.response = response
        lock.broadcast()
    }

    func cancelRequest(_ handle: Async.RequestHandle) {
        // Note, it's not an error if the request has already been completed or
        // even already gone from requests.
        lock.lock()
        if let req = requests.first(where: { $0.handle == handle }) {
            if req.response == nil {
                req.cancel()
                completeLocked(request: req, response: .cancelled)
            }
            lock.unlock()
            return
        }
        lock.unlock()
    }

    // Unblocks the interpreter thread without completing any specific request
    func interrupt() {
        lock.lock()
        defer {
            lock.unlock()
        }
        interrupted = true
        lock.broadcast()
    }

    private func removeCompletedRequest() -> Async.Response? {
        // lock must be held
        if let idx = requests.firstIndex(where: { $0.response != nil }) {
            let req = requests.remove(at: idx)
            req.scheduler = nil
            let response = Async.Response(handle: req.handle, value: req.response!)
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
            if interrupted {
                interrupted = false
                return Async.Response(handle: -1, value: .interrupt)
            } else if let response = removeCompletedRequest() {
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
