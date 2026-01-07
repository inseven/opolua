// Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe
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

class ConcurrentBox<T> {

    var condition = NSCondition()
    var value: T?

    init() {
    }

    init(_ value: T) {
        self.value = value
    }

    func put(_ value: T) {
        condition.lock()
        defer {
            condition.unlock()
        }
        while self.value != nil {
            condition.wait()
        }
        self.value = value
        condition.broadcast()
    }

    func tryPut(_ value: T) -> Bool {
        condition.lock()
        defer {
            condition.unlock()
        }
        if self.value != nil {
            return false
        }
        self.value = value
        condition.broadcast()
        return true
    }

    func trySwap(with value: T) -> T? {
        condition.lock()
        defer {
            condition.unlock()
        }
        let oldValue = self.value
        self.value = value
        condition.broadcast()
        return oldValue
    }

    func take() -> T {
        return tryTake(until: .distantFuture)!
    }

    func tryTake(until date: Date) -> T? {
        condition.lock()
        defer {
            condition.unlock()
        }
        while value == nil {
            print("Waiting until \(date)...")
            if !condition.wait(until: date) {
                return nil
            }
        }
        guard let value = self.value else {
            return nil
        }
        self.value = nil
        self.condition.broadcast()
        return value
    }

    func tryTake() -> T? {
        condition.lock()
        defer {
            condition.unlock()
        }
        guard let value = self.value else {
            return nil
        }
        self.value = nil
        self.condition.broadcast()
        return value
    }

    // TODO: swapWithValue -> This can be used to show the menu.
    // TODO: trySwapWithValue

}
