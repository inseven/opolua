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
    private var settingsSink: AnyCancellable?
    private var _items: Set<Directory.Item> = []
    private var interpreter = OpoInterpreter()

    var items: [Directory.Item] {
        return Array(_items)
    }
    weak var delegate: ProgramDetectorDelegate?

    init(settings: Settings) {
        self.settings = settings
        super.init()
        settings.addObserver(self)
    }

    static func find(url: URL, filter: (Directory.Item) -> Bool, interpreter: OpoInterpreter) throws -> [Directory.Item] {
        var result: [Directory.Item] = []
        for item in try Directory.items(for: url, interpreter: interpreter) {
            if filter(item) {
                result.append(item)
            }
            if case Directory.Item.ItemType.directory = item.type {
                result += try find(url: item.url, filter: filter, interpreter: interpreter)
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
            DispatchQueue.main.async {
                self._items = Set(items)
                self.delegate?.programDetectorDidUpdateItems(self)
            }
        } catch {
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

extension ProgramDetector: SettingsObserver {

    func settings(_ settings: Settings, didAddIndexableUrl indexableUrl: URL) {
        print("didAddIndexableUrl: \(indexableUrl)")
    }

    func settings(_ settings: Settings, didRemoveIndexableUrl indexableUrl: URL) {
        print("didRemoveIndexableUrl: \(indexableUrl)")
    }

}
