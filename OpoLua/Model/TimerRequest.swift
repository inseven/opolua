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
import Combine

/**
 A one-shot interval-based timer.
 */
class TimerRequest: Scheduler.Request {

    private let interval: Double
    private var cancellable: Cancellable?

    init(request: Async.Request) {
        precondition(request.type == .sleep && request.intVal != nil)
        self.interval = Double(request.intVal!) / 1000.0
        super.init(requestHandle: request.requestHandle)
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

    override func cancel() {
        cancellable?.cancel()
    }

}
