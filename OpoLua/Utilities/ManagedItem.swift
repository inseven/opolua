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

protocol ManagedItemDelegate: AnyObject {

    func managedItemDidPrepare(_ managedItem: ManagedItem)
    func managedItem(_ managedItem: ManagedItem, didFailToPrepareWithError error: Error)

}

/**
 Utility for managing access to both local and iCloud Drive files.

 Unfortunately, while the Apple documentation says we should use NSMetadataQuery (Sportlight APIs) to watch for changes to the download status of files, these don't actually appear to work for externally accessed APIs (the queries just return empty). This therefore hides away an ugly polling mechanism which--where necessary--kicks of the item download and then watches for its downloading status. There's a tiny silver lining to this approach in that NSMetadataQuery would require us to have iCloud entitlements which shouldn't actually be required for our specific use case.

 If anyone sees this and feels a bit 🤢, we're very open to improvement suggestions, or being told how to use NSMetadataQuery correctly.
 */
class ManagedItem {

    let url: URL
    var delegate: ManagedItemDelegate?

    private var isRunning = false
    private var timer: Timer?

    private func isDownloaded() throws -> Bool {
        return try url.ubiquitousItemDownloadingStatus() != .notDownloaded
    }

    init(url: URL) {
        self.url = url
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !isRunning else {
            return
        }
        isRunning = true
        guard FileManager.default.isUbiquitousItem(at: url) else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                self.delegate?.managedItemDidPrepare(self)
            }
            return
        }
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: self.url)
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
                guard let self = self else {
                    return
                }
                self.check()
            }
        } catch {
            delegate?.managedItem(self, didFailToPrepareWithError: error)
        }
    }

    private func check() {
        dispatchPrecondition(condition: .onQueue(.main))
        do {
            guard try self.isDownloaded() else {
                return
            }
            delegate?.managedItemDidPrepare(self)
            timer?.invalidate()
        } catch {
            delegate?.managedItem(self, didFailToPrepareWithError: error)
            timer?.invalidate()
        }
    }

}
