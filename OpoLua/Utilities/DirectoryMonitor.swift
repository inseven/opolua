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
import UIKit

/**
 Updates on the queue provided.
 */
protocol DirectoryMonitorDelegate: AnyObject {

    func directoryMonitor(_ directoryMonitor: DirectoryMonitor, contentsDidChangeForUrl url: URL)

}

class DirectoryMonitor {

    static var countLock = NSLock()

    static var count = 0

    static func incrementCount() {
        countLock.perform {
            count = count + 1
            print("open directory count = \(count)")
        }
    }

    static func decrementCount() {
        countLock.perform {
            count = count - 1
            print("open directory count = \(count)")

        }
    }

    enum State {
        case idle
        case running
        case cancelled
    }

    private static func dispatchSource(for url: URL, queue: DispatchQueue) throws -> DispatchSourceFileSystemObject {
        let directoryFileDescriptor = open(url.path, O_EVTONLY)
        guard directoryFileDescriptor > 0 else {
            throw NSError(domain: POSIXError.errorDomain, code: Int(errno), userInfo: nil)
        }
        #if DEBUG
        DirectoryMonitor.incrementCount()
        #endif
        let dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: directoryFileDescriptor,
                                                                       eventMask: [.write],
                                                                       queue: queue)
        dispatchSource.setCancelHandler {
            close(directoryFileDescriptor)
            #if DEBUG
            DirectoryMonitor.decrementCount()
            #endif
        }
        return dispatchSource
    }

    let url: URL
    private let queue: DispatchQueue
    private var dispatchSource: DispatchSourceFileSystemObject

    // We use a recursive lock here to allow clients to call `cancel` from within a delegate callback without causing
    // deadlock. Needless to say this means that we need to be careful about how we call delegates with the lock held,
    // but this is currently only done from one place (`queue_update`) which explicitly only calls the delegate at the
    // end of the method so there should be no state synchronization risk following that call.
    private var lock = NSRecursiveLock()
    private var _state: State = .idle  // Synchronized by lock.
    private var _delegate: DirectoryMonitorDelegate?  // Synchronized by lock.

    var delegate: DirectoryMonitorDelegate? {
        get {
            lock.perform {
                return _delegate
            }
        }
        set {
            lock.perform {
                _delegate = newValue
            }
        }
    }

    init(url: URL, queue: DispatchQueue) throws {
        self.url = url
        self.queue = DispatchQueue(label: "DirectoryMonitor.queue", attributes: .initiallyInactive)
        self.queue.setTarget(queue: queue)
        self.queue.activate()
        dispatchSource = try Self.dispatchSource(for: url, queue: self.queue)
        dispatchSource.setEventHandler { [weak self] in
            guard let self = self else {
                return
            }
            self.queue_update()
        }
    }

    deinit {
        cancel()
    }

    func start() {
        lock.perform {
            guard _state == .idle else {
                return
            }
            _state = .running
        }
        dispatchSource.resume()
    }

    func cancel() {
        lock.perform {
            guard _state == .running else {
                return
            }
            _state = .cancelled
        }
        dispatchSource.cancel()
    }

    private func queue_update() {
        dispatchPrecondition(condition: .onQueue(queue))
        lock.perform {
            guard _state == .running else {
                return
            }
            _delegate?.directoryMonitor(self, contentsDidChangeForUrl: url)
        }
    }

}
