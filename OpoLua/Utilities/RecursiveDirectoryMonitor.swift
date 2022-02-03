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

import Combine
import Foundation

class RecursiveDirectoryMonitor {

    fileprivate struct ObserverContext {

        let id = UUID()
        let url: URL
        let handler: () -> Void

    }

    class CancellableObserver: Cancellable {

        private weak var monitor: RecursiveDirectoryMonitor?
        private var context: ObserverContext

        var url: URL {
            return context.url
        }

        fileprivate init(monitor: RecursiveDirectoryMonitor, context: ObserverContext) {
            self.monitor = monitor
            self.context = context
        }

        deinit {
            cancel()
        }

        func cancel() {
            monitor?.cancel(context)
            monitor = nil
        }

    }

    enum State {
        case idle
        case running
    }

    static var shared: RecursiveDirectoryMonitor = {
        let monitor = RecursiveDirectoryMonitor(queue: DispatchQueue(label: "RecursiveDirectoryMonitor.shared.queue"))
        monitor.start()
        return monitor
    }()

    // Returns resolved symlinks.
    private static func directories(for url: URL) -> [URL] {
        var children: [URL] = []
        var paths: [URL] = [url]
        while let url = paths.popLast() {
            let files = FileManager.default.enumerator(at: url.resolvingSymlinksInPath(),
                                                       includingPropertiesForKeys: [.isDirectoryKey])
            while let fileUrl = files?.nextObject() as? URL {
                let resourceValues = try! fileUrl.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                if resourceValues.isSymbolicLink! {
                    let resolvedUrl = fileUrl.resolvingSymlinksInPath()
                    if resolvedUrl.isDirectory {
                        paths.insert(resolvedUrl, at: 0)
                    }
                    continue
                }
                guard resourceValues.isDirectory! else {
                    continue
                }
                children.append(fileUrl)
            }
        }
        return children
    }

    private let queue: DispatchQueue
    private var state: State = .idle

    private var monitors: [DirectoryMonitor] = []
    private var observers: [ObserverContext] = []

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func start() {
        queue.async { [weak self] in
            self?.queue_start()
        }
    }

    func observe(url: URL, handler: @escaping () -> Void) -> CancellableObserver {
        dispatchPrecondition(condition: .notOnQueue(queue))
        let context = ObserverContext(url: url, handler: handler)
        queue.async {
            self.queue_addObserver(context: context)
        }
        return CancellableObserver(monitor: self, context: context)
    }

    private func cancel(_ context: ObserverContext) {
        dispatchPrecondition(condition: .notOnQueue(queue))
        queue.sync {
            self.queue_removeObserver(context: context)
        }
    }

    private func queue_addObserver(context: ObserverContext) {
        dispatchPrecondition(condition: .onQueue(queue))
        observers.append(context)
        print("observers = \(observers.count)")
        queue_updateSubDirectoryMonitors()
    }

    private func queue_removeObserver(context: ObserverContext) {
        dispatchPrecondition(condition: .onQueue(queue))
        observers.removeAll { $0.id == context.id }
        print("observers = \(observers.count)")
        queue_updateSubDirectoryMonitors()
    }

    private func queue_start() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard state == .idle else {
            return
        }
        state = .running
    }

    private func queue_updateSubDirectoryMonitors() {
        dispatchPrecondition(condition: .onQueue(queue))

        // Get URLs of all our sub-directories.
        var urls = Set<URL>()
        for observer in observers {
            urls.insert(observer.url.resolvingSymlinksInPath())
            for url in Self.directories(for: observer.url) {
                urls.insert(url)
            }
        }

        // Remove the monitors for the existing URLs causing them to cancel.
        monitors.removeAll { !urls.contains($0.url) }

        // Filter the list of URLs to remove the ones we're already monitoring.
        for monitor in monitors {
            urls.remove(monitor.url)
        }

        // Create monitors for the new URLs.
        for url in urls {
            let monitor = DirectoryMonitor(url: url, queue: queue)
            monitor.delegate = self
            monitors.append(monitor)
            monitor.start()
        }
    }

}

extension RecursiveDirectoryMonitor: DirectoryMonitorDelegate {

    func directoryMonitor(_ directoryMonitor: DirectoryMonitor, contentsDidChangeForUrl url: URL) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard state == .running else {
            return
        }
        queue_updateSubDirectoryMonitors()
        for observer in observers {
            observer.handler()
        }
    }

    func directoryMonitor(_ directoryMonitor: DirectoryMonitor, didFailWithError error: Error) {
        dispatchPrecondition(condition: .onQueue(queue))
        monitors.removeAll { $0.url == directoryMonitor.url }
    }

}
