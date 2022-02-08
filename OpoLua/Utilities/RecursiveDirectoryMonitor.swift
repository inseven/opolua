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

        // TODO: Cancelling a RecursiveDirectoryMonitor observer doesn't guarantee it never receives callbacks #151
        //       https://github.com/inseven/opolua/issues/151
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
        let monitor = RecursiveDirectoryMonitor()
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

    private let syncQueue = DispatchQueue(label: "RecursiveDirectoryMonitor.syncQueue")
    private let monitorQueue = DispatchQueue(label: "RecursiveDirectoryMonitor.monitorQueue")
    private var state: State = .idle  // Synchronized on syncQueue
    private let updateQueue = ConcurrentQueue<URL>()

    private var monitors: [DirectoryMonitor] = []
    private var observers: [ObserverContext] = []

    init() {
    }

    func start() {
        syncQueue.async { [weak self] in
            self?.queue_start()
        }
    }

    func observe(url: URL, handler: @escaping () -> Void) -> CancellableObserver {
        let context = ObserverContext(url: url, handler: handler)
        syncQueue.async {
            self.queue_addObserver(context: context)
        }
        return CancellableObserver(monitor: self, context: context)
    }

    private func cancel(_ context: ObserverContext) {
        syncQueue.async {
            self.queue_removeObserver(context: context)
        }
    }

    private func queue_addObserver(context: ObserverContext) {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        observers.append(context)
        print("observers = \(observers.count)")
        scheduleUpdate(for: [context.url])
    }

    private func queue_removeObserver(context: ObserverContext) {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        observers.removeAll { $0.id == context.id }
        print("observers = \(observers.count)")
        scheduleUpdate(for: [context.url])
    }

    private func queue_start() {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        guard state == .idle else {
            return
        }
        state = .running
        scheduleUpdate(for: observers.map({ $0.url }))
    }

    private func queue_updateSubDirectoryMonitors() {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        // Don't do any work if we've been cancelled.
        guard state == .running else {
            return
        }

        // Get the list of items to process.
        // We actually throw this list of URLs away at the moment as we rescan all the directories, but it's
        // a good way to indicate that updates need to be performed and having the fine-grained list at this point is
        // helpful and aspirational for the future.
        var changedUrls: [URL] = []
        while let url = updateQueue.tryTakeFirst() {
            changedUrls.append(url)
        }

        // If there are no URLs to process, they must have been handled by the previous update run.
        guard changedUrls.count > 0 else {
            return
        }

        NSLog("Updating sub-directory monitors...")

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
        // Perhaps counterintuitively, we ignore errors here as it's quite possible for the directory we wish to monitor
        // to have disappeared in the time it takes us to set up and start the monitor. We may wish to ignore only
        // specific errors in the future.
        for url in urls {
            do {
                print("Creating monitor for '\(url)'...")
                let monitor = try DirectoryMonitor(url: url, queue: monitorQueue)
                monitor.delegate = self
                monitors.append(monitor)
                monitor.start()
            } catch {
                print("Failed to monitor directory with error '\(error)'.")
            }
        }

        // Once we can guarantee that we're listening for subsequent changes, we can safely notify our listeners.
        for observer in observers {
            observer.handler()
        }
    }

    private func scheduleUpdate(for urls: [URL]) {
        for url in urls {
            updateQueue.append(url)
        }
        syncQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.queue_updateSubDirectoryMonitors()
        }
    }

}

extension RecursiveDirectoryMonitor: DirectoryMonitorDelegate {

    func directoryMonitor(_ directoryMonitor: DirectoryMonitor, contentsDidChangeForUrl url: URL) {
        dispatchPrecondition(condition: .onQueue(monitorQueue))
        scheduleUpdate(for: [url])
    }

}
