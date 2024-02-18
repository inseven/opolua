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
import UIKit

/**
 Called on the main queue.
 */
protocol DirectoryDelegate: AnyObject {

    func directoryDidUpdate(_ directory: Directory)
    func directory(_ directory: Directory, didFailWithError error: Error)

}

class Directory {

    struct Item: Hashable {

        static func == (lhs: Directory.Item, rhs: Directory.Item) -> Bool {
            return lhs.url == rhs.url
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(url)
        }

        enum ItemType {
            case object
            case directory
            case application(ApplicationMetadata?)
            case system(URL, ApplicationMetadata?)
            case installer
            case applicationInformation(ApplicationMetadata?)
            case image
            case sound
            case help
            case text
            case epocText // Ie conceptually plain text, but requiring going through OpoInterpreter to parse
            case opl
            case unknown
        }

        let url: URL
        let type: ItemType
        var icon: Icon
        var isWriteable: Bool

        init(url: URL, type: ItemType, isWriteable: Bool) {
            self.url = url
            self.type = type
            self.icon = type.icon()
            self.isWriteable = isWriteable
        }

        var name: String {
            switch type {
            case .system(_, let appInfo):
                return appInfo?.caption ?? url.lastPathComponent
            default:
                return url.lastPathComponent
            }
        }

        var programUrl: URL? {
            switch type {
            case .object:
                return url
            case .application:
                return url
            case .system(let url, _):
                return url
            default:
                return nil
            }
        }

    }

    enum State {
        case idle
        case running
    }

    static func defaultSort() -> (Directory.Item, Directory.Item) -> Bool {
        return { (item1: Directory.Item, item2: Directory.Item) -> Bool in
            let nameOrder = item1.name.localizedStandardCompare(item2.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            return item1.url.absoluteString.compare(item2.url.absoluteString) == .orderedAscending
        }
    }

    static func item(for url: URL, isWriteable: Bool = false, interpreter: OpoInterpreter) throws -> Item {

        let ext = url.pathExtension.lowercased()
        if FileManager.default.directoryExists(atPath: url.path) {
            // Check for an app 'bundle'.
            if let type = try Item.system(url: url, interpreter: interpreter) {
                return Item(url: url, type: type, isWriteable: isWriteable)
            } else {
                return Item(url: url, type: .directory, isWriteable: isWriteable)
            }
        } else if ext == "opo" {
            return Item(url: url, type: .object, isWriteable: isWriteable)
        } else if url.isApplication {
            return Item(url: url,
                        type: .application(interpreter.cachedAppInfo(forApplicationUrl: url)),
                        isWriteable: isWriteable)
        } else if ext == "sis" {
            return Item(url: url, type: .installer, isWriteable: isWriteable)
        } else if ext == "hlp" {
            return Item(url: url, type: .help, isWriteable: isWriteable)
        } else if ext == "txt" {
            return Item(url: url, type: .text, isWriteable: isWriteable)
        } else if ext == "mbm" || ext == "pic" {
            // Image files aren't always guaranteed to have the correct UIDs, so we also match on the file extension.
            return Item(url: url, type: .image, isWriteable: isWriteable)
        } else {
            switch interpreter.cachedRecognize(url: url) {
            case .aif:
                if let info = interpreter.cachedAppInfo(for: url) {
                    return Item(url: url, type: .applicationInformation(info), isWriteable: isWriteable)
                }
            case .mbm:
                return Item(url: url, type: .image, isWriteable: isWriteable)
            case .opl:
                return Item(url: url, type: .opl, isWriteable: isWriteable)
            case .sound:
                return Item(url: url, type: .sound, isWriteable: isWriteable)
            case .text:
                return Item(url: url, type: .epocText, isWriteable: isWriteable)
            default:
                break
            }
            return Item(url: url, type: .unknown, isWriteable: isWriteable)
        }
    }

    static func items(for url: URL, interpreter: OpoInterpreter) throws -> [Item] {
        let fileManager = FileManager.default
        let isWriteable = fileManager.isWritableFile(atPath: url.path)

        // We use the `enumerator` to ensure we can list hidden files.
        let contentsEnumerator = fileManager.enumerator(at: url.resolvingSymlinksInPath(),
                                                        includingPropertiesForKeys: [],
                                                        options: [.skipsSubdirectoryDescendants])
        var urls: [URL] = []
        while let url = contentsEnumerator?.nextObject() as? URL {
            urls.append(url)
        }

        let items = try urls
            .filter { !$0.lastPathComponent.starts(with: ".") }
            .compactMap { url -> Item? in
                return try item(for: url, isWriteable: isWriteable, interpreter: interpreter)
            }
            .sorted(by: Directory.defaultSort())
        return items
    }

    let url: URL
    var items: [Item] = []
    private var state: State = .idle

    weak var delegate: DirectoryDelegate?

    private let updateQueue = DispatchQueue(label: "Directory.updateQueue")
    private let interpreter = OpoInterpreter()
    private var observer: RecursiveDirectoryMonitor.CancellableObserver?

    var localizedName: String {
        return url.localizedName
    }

    init(url: URL) {
        self.url = url
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard state == .idle else {
            return
        }
        state = .running
        observer = RecursiveDirectoryMonitor.shared.observe(url: url) { [weak self] in
            self?.updateQueue.async {
                self?.updateQueue_refresh()
            }
        }
        refresh()
    }

    private func updateQueue_refresh() {
        dispatchPrecondition(condition: .onQueue(updateQueue))
        do {
            let items = try Self.items(for: url, interpreter: interpreter)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                self.items = items
                self.delegate?.directoryDidUpdate(self)
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                self.delegate?.directory(self, didFailWithError: error)
            }
        }

    }

    func refresh() {
        updateQueue.async { [weak self] in
            self?.updateQueue_refresh()
        }
    }
    
}

extension Directory.Item {

    static func system(url: URL, interpreter: OpoInterpreter) throws -> ItemType? {
        guard try FileManager.default.isSystem(at: url) else {
            return nil
        }

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url,
                                                      includingPropertiesForKeys: [.isDirectoryKey],
                                                      options: [.skipsHiddenFiles], errorHandler: { _, _ in return false }) else {
            return nil
        }

        let apps = enumerator
            .map { $0 as! URL }
            .filter { $0.isApplication }

        guard apps.count == 1,
              let url = apps.first else {
            return nil
        }
        return .system(url, interpreter.cachedAppInfo(forApplicationUrl: url))
    }

    func configurationActions(errorHandler: @escaping (Error) -> Void) -> [UIMenuElement] {
        guard let programUrl = programUrl, isWriteable else {
            return []
        }
        let appInfo = OpoInterpreter().cachedAppInfo(for: programUrl)
        let defaultDevice = Device.getDefault(forEra: appInfo?.appInfo.era)
        var configuration = Configuration.load(for: programUrl, defaultDevice: defaultDevice)
        var actions: [UIMenuElement] = []
        let runAsActions = Device.allCases.map { device -> UIAction in
            return UIAction(title: device.name, state: configuration.device == device ? .on : .off) { action in
                configuration.device = device
                do {
                    try configuration.save(for: programUrl)
                } catch {
                    errorHandler(error)
                }
            }
        }
        let runAsMenu = UIMenu(options: [.displayInline], children: runAsActions)
        actions.append(runAsMenu)
        return actions
    }

}

extension Directory.Item.ItemType {

    func icon() -> Icon {
        switch self {
        case .object:
            return .opo()
        case .directory:
            return .folder()
        case .application(let appInfo):
            return appInfo?.cachedIcon() ?? .unknownApplication()
        case .system(_, let appInfo):
            return appInfo?.cachedIcon() ?? .unknownApplication()
        case .installer:
            return .installer()
        case .applicationInformation(let appInfo):
            return appInfo?.cachedIcon() ?? .unknownApplication()
        case .image:
            return .image()
        case .sound:
            return .sound()
        case .help:
            return .data()
        case .text, .epocText:
            return .text()
        case .opl:
            return .opl()
        case .unknown:
            return .unknownFile()
        }
    }

}
