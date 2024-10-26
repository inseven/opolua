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

import Combine
import Foundation

class RecursiveDirectoryMonitor {

    fileprivate class ObserverContext {

        let id = UUID()
        let url: URL
        private let handler: (() -> Void)!
        private let errorHandler: (Error) -> Void
        private let stateLock = NSRecursiveLock()
        private var isCancelled = false  // Synchronized with stateLock

        init(url: URL, handler: @escaping () -> Void, errorHandler: @escaping (Error) -> Void) {
            self.url = url
            self.handler = handler
            self.errorHandler = errorHandler
        }

        func notify() {
            stateLock.withLock {
                guard !self.isCancelled else {
                    return
                }
                handler()
            }
        }

        func cancelWithError(_ error: Error) {
            stateLock.withLock {
                guard !self.isCancelled else {
                    return
                }
                isCancelled = true
                errorHandler(error)
            }
        }

        func cancel() {
            stateLock.withLock {
                isCancelled = true
            }
        }

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
        case cancelled
    }

    static let maximumDirectoryCount = 20

    static var shared: RecursiveDirectoryMonitor = {
        let monitor = RecursiveDirectoryMonitor()
        monitor.start()
        return monitor
    }()

    // Returns resolved symlinks.
    private static func directories(for url: URL) -> [URL] {
        var children: [URL] = []
        let files = FileManager.default.enumerator(at: url.resolvingSymlinksInPath(),
                                                   includingPropertiesForKeys: [.isDirectoryKey],
                                                   options: [.skipsSubdirectoryDescendants])
        while let fileUrl = files?.nextObject() as? URL {
            let resourceValues = try! fileUrl.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if resourceValues.isSymbolicLink! {
                let resolvedUrl = fileUrl.resolvingSymlinksInPath()
                if resolvedUrl.isDirectory {
                    children.insert(resolvedUrl, at: 0)
                }
                continue
            }
            guard resourceValues.isDirectory! else {
                continue
            }
            children.append(fileUrl)
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

    func observe(url: URL,
                 handler: @escaping () -> Void,
                 errorHandler: @escaping (Error) -> Void = { _ in }) -> CancellableObserver {
        let context = ObserverContext(url: url, handler: handler, errorHandler: errorHandler)
        syncQueue.async {
            self.queue_addObserver(context: context)
        }
        return CancellableObserver(monitor: self, context: context)
    }

    private func cancel(_ context: ObserverContext) {
        context.cancel()  // Guarantees the observer will never receive subsequent updates on return.
        syncQueue.async {
            self.queue_removeObserver(context: context)
        }
    }

    private func queue_addObserver(context: ObserverContext) {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        guard state != .cancelled else {
            context.cancelWithError(OpoLuaError.cancelled)
            return
        }

        // Only schedule a full update if the URL is one we're not already monitoring.
        let isNewUrl = !monitors.contains { $0.url == context.url.resolvingSymlinksInPath() }

        observers.append(context)
        print("observers = \(observers.count)")

        if isNewUrl {
            scheduleUpdate(for: [context.url])
        } else {
            context.notify()
        }
    }

    private func queue_removeObserver(context: ObserverContext) {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        observers.removeAll { $0.id == context.id }
        print("observers = \(observers.count)")

        // Only schedule a full update if the URL isn't still being monitored by an existing observer.
        let isStillMonitoringUrl = observers.contains { $0.url == context.url }

        if !isStillMonitoringUrl {
            scheduleUpdate(for: observers.map { $0.url })
        }
    }

    private func queue_start() {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        guard state == .idle else {
            return
        }
        state = .running
        scheduleUpdate(for: observers.map({ $0.url }))
    }

    // Checks to see if there's an existing `DirectoryMonitor` for the requested URL and, if not, creates, adds, and
    // starts a new instance for the specified URL.
    // Throws if creating a new monitor would cause the number of open directories to exceed the specified maximum.
    private func queue_createMonitorIfNecessary(url: URL) throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        guard !monitors.contains(where: { $0.url == url }) else {
            // There's already a monitor; nothing to do.
            return
        }

        // Ensure that we've not reached our (self-imposed) directory maximum.
        guard monitors.count < Self.maximumDirectoryCount else {
            throw OpoLuaError.exceededMaximumDirectoryCount
        }

        // Create monitors for the new URLs.
        // Perhaps counterintuitively, we ignore errors here as it's quite possible for the directory we wish to monitor
        // to have disappeared in the time it takes us to set up and start the monitor. We may wish to ignore only
        // specific errors in the future.
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

    private func queue_cancelWithError(_ error: Error) {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        for observer in observers {
            observer.cancelWithError(error)
        }
        observers.removeAll()
        for monitor in monitors {
            monitor.cancel()
        }
        monitors.removeAll()
        state = .cancelled
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

        // Walk the directory structure setting up new directory monitors for each directory we find.
        // We perform a breadth-first walk, creating and starting directory monitors for parent directory before
        // recursing into its sub-directories to ensure we don't miss any changes as we go.
        var directoryUrlsToExplore = Array(Set(observers.map { $0.url.resolvingSymlinksInPath() }))
        var discoveredDirectoryUrls = Set<URL>()
        while let directoryUrl = directoryUrlsToExplore.popLast() {

            do {

                // Maintain a set of the URLs we've seen during this process to allow us to clean up observers for
                // deleted directories at the end.
                discoveredDirectoryUrls.insert(directoryUrl)

                // Check to see if there's already a monitor for the URL; if not, set one up.
                try queue_createMonitorIfNecessary(url: directoryUrl)

                // Get all the immediate sub-directories of the current directory and add them to the queue to explore.
                for url in Self.directories(for: directoryUrl) {
                    directoryUrlsToExplore.insert(url, at: 0)
                }

            } catch {
                queue_cancelWithError(error)
                return
            }

        }

        // Remove the monitors for the missing URLs causing them to cancel.
        monitors.removeAll { !discoveredDirectoryUrls.contains($0.url) }

        // Once we can guarantee that we're listening for subsequent changes, we can safely notify our listeners.
        for observer in observers {
            observer.notify()
        }
    }

    private func scheduleUpdate(for urls: [URL]) {
        for url in urls {
            updateQueue.append(url)
        }
        syncQueue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
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
