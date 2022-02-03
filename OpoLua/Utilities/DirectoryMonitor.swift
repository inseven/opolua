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
import GameController

/**
 Updates on the queue provided.
 */
protocol DirectoryMonitorDelegate: AnyObject {

    func directoryMonitor(_ directoryMonitor: DirectoryMonitor, contentsDidChangeForUrl url: URL)
    func directoryMonitor(_ directoryMonitor: DirectoryMonitor, didFailWithError error: Error)

}

class DirectoryMonitor {

    static var countLock = NSLock()

    static var count = 0

    static func incrementCount() {
        countLock.lock()
        defer {
            countLock.unlock()
        }
        count = count + 1
        print("open directory count = \(count)")
    }

    static func decrementCount() {
        countLock.lock()
        defer {
            countLock.unlock()
        }
        count = count - 1
        print("open directory count = \(count)")
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
    private var state: State = .idle
    private var dispatchSource: DispatchSourceFileSystemObject?

    weak var delegate: DirectoryMonitorDelegate?

    // N.B. This does not resolve symlinks in the URL.
    init(url: URL, queue: DispatchQueue = .main) {
        self.url = url
        self.queue = queue
    }

    deinit {
        dispatchSource?.cancel()
    }

    func start() {
        queue.async { [weak self] in
            self?.queue_start()
        }
    }

    func cancel() {
        queue.async {
            self.queue_cancel()
        }
    }

    private func queue_start() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard state == .idle else {
            return
        }
        state = .running
        do {
            dispatchSource = try Self.dispatchSource(for: url, queue: queue)
            dispatchSource?.setEventHandler { [weak self] in
                guard let self = self else {
                    return
                }
                self.queue_update()
            }
            dispatchSource?.resume()
        } catch {
            queue_cancelWithError(error)
        }
    }

    private func queue_cancel() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard state == .running else {
            return
        }
        state = .cancelled
        dispatchSource?.cancel()
        dispatchSource = nil
    }

    private func queue_cancelWithError(_ error: Error) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard state == .running else {
            return
        }
        queue_cancel()
        delegate?.directoryMonitor(self, didFailWithError: error)
    }

    private func queue_update() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard state == .running else {
            return
        }
        delegate?.directoryMonitor(self, contentsDidChangeForUrl: url)
    }

}
