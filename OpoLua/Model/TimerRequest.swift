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

    private enum TimerType {
        case interval(TimeInterval)
        case date(Date)
    }
    private let type: TimerType
    private var workItem: DispatchWorkItem!

    init(handle: Async.RequestHandle, after interval: TimeInterval) {
        self.type = .interval(interval)
        super.init(handle: handle)
        self.workItem = DispatchWorkItem(block: {
            self.scheduler?.complete(request: self, response: .completed)
        })
    }

    init(handle: Async.RequestHandle, at date: Date) {
        self.type = .date(date)
        super.init(handle: handle)
        self.workItem = DispatchWorkItem(block: {
            self.scheduler?.complete(request: self, response: .completed)
        })
    }

    override func start() {
        switch type {
        case .interval(let interval):
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + interval, execute: workItem)
        case .date(let date):
            // No better way to get a DispatchWallTime from a Date? It probably doesn't matter for our purposes...
            let delta = date.timeIntervalSince(Date.now)
            DispatchQueue.main.asyncAfter(wallDeadline: DispatchWallTime.now() + delta, execute: workItem)
        }
    }

    override func cancel() {
        workItem.cancel()
    }

}
