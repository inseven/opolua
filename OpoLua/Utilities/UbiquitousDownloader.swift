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

class UbiquitousDownloader {

    private let settings: Settings
    private let indexableLocationObserver: IndexableLocationObserver
    private let rateLimiter = RateLimiter(delay: .microseconds(400))

    init(settings: Settings) {
        self.settings = settings
        indexableLocationObserver = IndexableLocationObserver(settings: settings)
        indexableLocationObserver.delegate = self
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        indexableLocationObserver.start()
    }

    func update() {
        dispatchPrecondition(condition: .onQueue(.main))
        let indexableUrls = settings.indexableUrls
        rateLimiter.perform {
            print("Scanning for new ubiquitous files...")
            let startDate = Date()
            for url in indexableUrls {
                FileManager.default.startDownloadingUbitquitousItemsRecursive(for: url)
            }
            let elapsedTime = Date().timeIntervalSince(startDate)
            print("Completed scan for new ubiquitous files in \(String(format: "%.2f", elapsedTime)) seconds.")
        }
    }

}

extension UbiquitousDownloader: IndexableLocationObserverDelegate {

    func indexableLocationObserver(_ indexableLocationObserver: IndexableLocationObserver,
                                   didUpdateIndexableContents indexableContents: [URL]) {
        DispatchQueue.main.async {
            self.update()
        }
    }

    func indexableLocationObserver(_ indexableLocationObserver: IndexableLocationObserver,
                                   didFailWithError error: Error) {
    }

}
