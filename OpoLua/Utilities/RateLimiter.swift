// Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe
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

class RateLimiter {

    private typealias Task = () -> Void

    private let delay: DispatchTimeInterval
    private let queue = DispatchQueue(label: "RateLimiter.queue")
    private let task = ConcurrentBox<Task>()

    init(delay: DispatchTimeInterval) {
        self.delay = delay
    }

    func perform(task: @escaping () -> Void) {
        _ = self.task.trySwap(with: task)
        queue.asyncAfter(deadline: .now() + delay) {
            guard let task = self.task.tryTake() else {
                // There's no task to be performed; give up.
                return
            }
            task()
        }
    }

}
