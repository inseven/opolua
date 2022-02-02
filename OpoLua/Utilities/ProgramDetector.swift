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

// TODO: This should be an observer
protocol ProgramDetectorDelegate: AnyObject {

    func programDetectorDidUpdateItems(_ programDetector: ProgramDetector)
    func programDetector(_ programDetector: ProgramDetector, didFailWithError error: Error)

}

class ProgramDetector: NSObject {

    private var settings: Settings
    private let updateQueue = DispatchQueue(label: "ProgramDetector.updateQueue")
    private var _items: [Directory.Item] = []
    private var interpreter = OpoInterpreter()

    private var monitors: [DirectoryMonitor] = []

    var items: [Directory.Item] {
        return _items
    }
    weak var delegate: ProgramDetectorDelegate?

    init(settings: Settings) {
        self.settings = settings
        super.init()
    }

    static func find(url: URL, filter: (Directory.Item) -> Bool, interpreter: OpoInterpreter) throws -> [Directory.Item] {
        var result: [Directory.Item] = []
        for item in try Directory.items(for: url, interpreter: interpreter) {
            if filter(item) {
                result.append(item)
            }
            if case Directory.Item.ItemType.directory = item.type {
                // Without this, the memory usage of this recursive find operation balloons and the application is
                // killed with an OOM.
                try autoreleasepool {
                    result += try find(url: item.url, filter: filter, interpreter: interpreter)
                }
            }
        }
        return result
    }

    func updateQueue_update(urls: [URL]) {
        dispatchPrecondition(condition: .onQueue(updateQueue))
        do {
            var items: [Directory.Item] = []
            for url in urls {
                items += try Self.find(url: url, filter: { item in
                    switch item.type {
                    case .object, .system, .application:
                        return true
                    default:
                        return false
                    }
                }, interpreter: interpreter)
            }
            let uniqueItems = Array(Set(items))
            DispatchQueue.main.async {
                self._items = uniqueItems
                self.delegate?.programDetectorDidUpdateItems(self)
            }
        } catch {
            DispatchQueue.main.async {
                self.delegate?.programDetector(self, didFailWithError: error)
            }
        }

    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        settings.addObserver(self)
        for indexableUrl in settings.indexableUrls {
            let monitor = DirectoryMonitor(url: indexableUrl, recursive: true)
            monitor.delegate = self
            monitors.append(monitor)
            monitor.start()
        }
        self.update()
    }

    private func update() {
        dispatchPrecondition(condition: .onQueue(.main))
        let urls = settings.indexableUrls
        print(urls)
        print("Indexing \(urls.count) items...")
        updateQueue.async {
            self.updateQueue_update(urls: urls)
        }
    }

}

extension ProgramDetector: SettingsObserver {

    func settings(_ settings: Settings, didAddIndexableUrl indexableUrl: URL) {
        let monitor = DirectoryMonitor(url: indexableUrl, recursive: true)
        monitor.delegate = self
        monitors.append(monitor)
        monitor.start()
        self.update()
    }

    func settings(_ settings: Settings, didRemoveIndexableUrl indexableUrl: URL) {
        for monitor in monitors {
            guard monitor.url == indexableUrl else {
                continue
            }
            monitor.cancel()
        }
        monitors.removeAll { $0.url == indexableUrl }
        self.update()
    }

}

extension ProgramDetector: DirectoryMonitorDelegate {

    func directoryMonitor(_ directoryMonitor: DirectoryMonitor, contentsDidChangeForUrl url: URL) {
        self.update()
    }

    func directoryMonitor(_ directoryMonitor: DirectoryMonitor, didFailWithError error: Error) {
        print("Directory monitoring failed with error \(error).")
        self.monitors.removeAll { $0.url == directoryMonitor.url }
    }

}
