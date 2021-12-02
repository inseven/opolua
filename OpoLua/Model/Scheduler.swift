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

    var requests: [Int32: Async.Request] = [:]
    var responses: [Int32: Async.Response] = [:]

    var lock = NSCondition()

    init() {
    }

    func scheduleRequest(_ request: Async.Request) {
        print("schedule request \(request.type)")
        lock.lock()
        defer {
            lock.broadcast()
            lock.unlock()
        }
        requests[request.requestHandle] = request
    }

    func serviceRequest(type: Async.RequestType, completion: (Async.Request) -> Async.Response) {
        lock.lock()
        defer {
            lock.broadcast()
            lock.unlock()
        }
        for (_, request) in requests {
            if request.type == type {
                responses[request.requestHandle] = completion(request)
                return
            }
        }
    }

    func touchesBegan(_ touches: UITouch) {
        serviceRequest(type: .getevent) { request in
            let event = Async.PenEvent(timestamp: 0, windowId: 0, type: .down, modifiers: 0, x: 0, y: 0)
            return Async.Response(type: .getevent,
                                  requestHandle: request.requestHandle,
                                  value: .penevent(event))
        }
    }

    func cancelRequest(_ requestHandle: Int32) {
        lock.lock()
        requests.removeValue(forKey: requestHandle)
        // TODO: Signal with an event.
        lock.unlock()
    }

    func waitForRequest(_ requestHandle: Int32) -> Async.Response {
        repeat {
            lock.lock()
            if let response = responses.removeValue(forKey: requestHandle) {
                lock.unlock()
                return response
            } else {
                lock.wait()
            }
        } while true
    }

    func waitForAnyRequest() -> Async.Response {
        lock.lock()
        repeat {
            print("waitForAnyRequest")
            print("waitForAnyRequest obtained lock")
            if let response = responses.removeRandomValue() {
                print("sending response \(response.type) for handle \(response.requestHandle)")
                lock.unlock()
                return response
            } else {
                print("no value; waiting")
                lock.wait()
            }
        } while true
    }

}
