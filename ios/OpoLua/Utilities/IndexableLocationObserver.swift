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

// Called on IndexableLocationObserver.targetQueue
protocol IndexableLocationObserverDelegate: AnyObject {

    func indexableLocationObserver(_ indexableLocationObserver: IndexableLocationObserver,
                                   didUpdateIndexableContents indexableContents: [URL])
    func indexableLocationObserver(_ indexableLocationObserver: IndexableLocationObserver,
                                   didFailWithError error: Error)

}

class IndexableLocationObserver: NSObject {

    private let settings: Settings
    private let updateQueue = DispatchQueue(label: "UbiquitousFileDownloader.updateQueue",
                                            attributes: .initiallyInactive)
    private var observers: [RecursiveDirectoryMonitor.CancellableObserver] = []

    weak var delegate: IndexableLocationObserverDelegate?

    init(settings: Settings, targetQueue: DispatchQueue? = nil) {
        self.settings = settings
        super.init()
        updateQueue.setTarget(queue: targetQueue)
        updateQueue.activate()
    }

    private func observeIndexableUrl(_ indexableUrl: URL) {
        let observer = RecursiveDirectoryMonitor.shared.observe(url: indexableUrl) { [weak self] in
            DispatchQueue.main.async {
                self?.update()
            }
        } errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                self?.cancelWithError(error)
            }
        }
        observers.append(observer)
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        settings.addObserver(self)
        for indexableUrl in settings.indexableUrls {
            observeIndexableUrl(indexableUrl)
        }
        self.update()
    }

    func update() {
        dispatchPrecondition(condition: .onQueue(.main))
        let urls = settings.indexableUrls
        updateQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.delegate?.indexableLocationObserver(self, didUpdateIndexableContents: urls)
        }
    }

    func cancelWithError(_ error: Error) {
        dispatchPrecondition(condition: .onQueue(.main))
        settings.removeObserver(self)
        for observer in observers {
            observer.cancel()
        }
        observers.removeAll()
        updateQueue.async {
            self.delegate?.indexableLocationObserver(self, didFailWithError: error)
        }
    }

}

extension IndexableLocationObserver: SettingsObserver {

    func settings(_ settings: Settings, didAddIndexableUrl indexableUrl: URL) {
        dispatchPrecondition(condition: .onQueue(.main))
        observeIndexableUrl(indexableUrl)
        self.update()
    }

    func settings(_ settings: Settings, didRemoveIndexableUrl indexableUrl: URL) {
        dispatchPrecondition(condition: .onQueue(.main))
        observers.removeAll { $0.url == indexableUrl }
        self.update()
    }

}
