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

class ProgramDetector {

    private var settings: Settings
    private let updateQueue = DispatchQueue(label: "ProgramDetector.updateQueue")
    private var settingsSink: AnyCancellable?
    private var _items: [Directory.Item] = []

    var items: [Directory.Item] {
        return _items
    }
    weak var delegate: ProgramDetectorDelegate?

    init(settings: Settings) {
        self.settings = settings
    }

    func updateQueue_update(urls: [URL]) {
        dispatchPrecondition(condition: .onQueue(updateQueue))
        print("Fetching items...")
        do {
            var items: [Directory.Item] = []
            for url in urls {
                items = items + (try Directory.items(for: url))
            }
            items = items.filter { item in
                switch item.type {
                case .object:
                    return true
                case .directory:
                    return false
                case .application(_):
                    return true
                case .system(_, _):
                    return true
                case .installer:
                    return false
                case .applicationInformation(_):
                    return false
                case .image:
                    return false
                case .sound:
                    return false
                case .help:
                    return false
                case .unknown:
                    return false
                }
            }
            DispatchQueue.main.async {
                print("Succeeded!")
                self._items = items
                self.delegate?.programDetectorDidUpdateItems(self)
            }
        } catch {
            print("Failed!")
            DispatchQueue.main.async {
                self.delegate?.programDetector(self, didFailWithError: error)
            }
        }

    }

    func start() {
        settingsSink = settings.objectWillChange.sink { [weak self] _ in
            guard let self = self else {
                return
            }
            self.update()
        }
        self.update()
    }

    private func update() {
        let urls = settings.indexableUrls
        updateQueue.async {
            self.updateQueue_update(urls: urls)
        }
    }

}
