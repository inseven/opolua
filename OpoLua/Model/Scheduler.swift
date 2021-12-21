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

class Scheduler {

    class Request {

        let request: Async.Request
        private let completion: (Async.ResponseValue) -> Void

        private var lock = NSLock()
        private var _cancelled: Bool = false

        init(request: Async.Request, completion: @escaping (Async.ResponseValue) -> Void) {
            self.request = request
            self.completion = completion
        }

        var cancelled: Bool {
            get {
                lock.lock()
                defer {
                    lock.unlock()
                }
                return _cancelled
            }
            set {
                lock.lock()
                defer {
                    lock.unlock()
                }
                _cancelled = newValue
            }
        }

        func cancel() {
            cancelled = true
        }

        func complete(_ value: Async.ResponseValue) {
            completion(value)
        }

    }

    var requests: [Int32: Request] = [:]
    var responses: [Int32: Async.Response] = [:]
    var handlers: [Async.RequestType: (Request) -> Void] = [:]
    var lock = NSCondition()
    var handlerQueue = DispatchQueue(label: "Scheduler.handlerQueue", attributes: .concurrent)

    func addHandler(_ type: Async.RequestType,
                    handler: @escaping (Request) -> Void) {
        lock.lock()
        defer {
            lock.unlock()
        }
        self.handlers[type] = handler
    }

    func scheduleRequest(_ request: Async.Request) {
        lock.lock()
        defer {
            lock.unlock()
        }
        assert(requests[request.requestHandle] == nil)
        let wrapper = Request(request: request) { responseValue in
            self.serviceRequest(request.requestHandle, responseValue: responseValue)
        }
        requests[request.requestHandle] = wrapper
        lock.broadcast()
        let handler = handlers[request.type]!
        handlerQueue.async {
            handler(wrapper)
        }
    }

    private func serviceRequest(_ requestHandle: Int32, responseValue: Async.ResponseValue) {
        lock.lock()
        defer {
            lock.unlock()
        }
        let request = requests.removeValue(forKey: requestHandle)!
        responses[requestHandle] = Async.Response(requestHandle: request.request.requestHandle, value: responseValue)
        lock.broadcast()
    }

    func cancelRequest(_ requestHandle: Int32) {
        lock.lock()
        defer {
            lock.unlock()
        }
        let request = requests[requestHandle]!
        request.cancel()
    }

    func waitForAnyRequest() -> Async.Response {
        lock.lock()
        defer {
            lock.unlock()
        }
        repeat {
            if let response = responses.removeRandomValue() {
                // print("waitForAnyRequest -> \(response)")
                lock.broadcast()
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
        guard let response = responses.removeRandomValue() else {
            // print("anyRequest -> nil")
            return nil
        }
        // print("anyRequest -> \(response)")
        lock.broadcast()
        return response
    }

}
