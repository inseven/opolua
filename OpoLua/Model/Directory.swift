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
import UIKit

protocol DirectoryDelegate: AnyObject {

    func directoryDidChange(_ directory: Directory)

}

extension Directory.Item.ItemType {

    func icon() -> Icon {
        switch self {
        case .object:
            return .opo
        case .directory:
            return .folder
        case .application(let appInfo):
            return appInfo?.icon() ?? .unknownApplication
        case .system(_, let appInfo):
            return appInfo?.icon() ?? .unknownApplication
        case .installer:
            return .installer
        case .applicationInformation(let appInfo):
            return appInfo?.icon() ?? .unknownApplication
        case .image:
            return .image
        case .sound:
            return .sound
        case .help:
            return .data
        case .text:
            return .opl
        case .unknown:
            return .unknownFile
        }
    }

}

class Directory {

    static func appInfo(forApplicationUrl url: URL) -> OpoInterpreter.AppInfo? {
        guard let applicationInfoFile = url.applicationInfoUrl,
              FileManager.default.fileExists(atUrl: applicationInfoFile)
        else {
            return nil
        }
        return OpoInterpreter.shared.getAppInfo(aifPath: applicationInfoFile.path)
    }

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
            case application(OpoInterpreter.AppInfo?)
            case system(URL, OpoInterpreter.AppInfo?)
            case installer
            case applicationInformation(OpoInterpreter.AppInfo?)
            case image
            case sound
            case help
            case text
            case unknown
        }

        let url: URL
        let type: ItemType
        var icon: Icon

        init(url: URL, type: ItemType) {
            self.url = url
            self.type = type
            self.icon = type.icon()
        }

        var name: String {
            switch type {
            case .object, .image, .text:
                return url.lastPathComponent.deletingPathExtension
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
            case .directory:
                return nil
            case .application:
                return url
            case .system(let url, _):
                return url
            case .installer:
                return nil
            case .applicationInformation:
                return nil
            case .image:
                return nil
            case .sound:
                return nil
            case .help:
                return nil
            case .text:
                return nil
            case .unknown:
                return nil
            }
        }

    }

    private static func asSystem(url: URL) throws -> Item.ItemType? {
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
        let appInfo = Directory.appInfo(forApplicationUrl: url)
        if appInfo == nil {
            print("Failed to find AIF for '\(url.lastPathComponent)'.")
        }
        return .system(url, appInfo)
    }

    let url: URL
    var items: [Item] = []

    weak var delegate: DirectoryDelegate?

    private let updateQueue = DispatchQueue(label: "Directory.updateQueue")

    var name: String {
        return url.name
    }
    
    init(url: URL) throws {
        self.url = url
        self.refresh()
    }

    func items(filter: String?) -> [Item] {
        return items.filter { item in
            guard let filter = filter,
                  !filter.isEmpty
            else {
                return true
            }
            return item.name.localizedCaseInsensitiveContains(filter)
        }
    }

    func refresh() {
        updateQueue.async {
            do {
                let items = try Self.items(for: self.url)
                DispatchQueue.main.async {
                    self.items = items
                    self.delegate?.directoryDidChange(self)
                }
            } catch {
                // TODO: Report this error
                print("Failed to get items with error \(error)")
            }
        }
    }

    static func items(for url: URL) throws -> [Item] {
        let items = try url.contents
            .filter { !$0.lastPathComponent.starts(with: ".") }
            .compactMap { url -> Item? in
                if FileManager.default.directoryExists(atPath: url.path) {
                    // Check for an app 'bundle'.
                    if let type = try Self.asSystem(url: url) {
                        return Item(url: url, type: type)
                    } else {
                        return Item(url: url, type: .directory)
                    }
                } else if url.pathExtension.lowercased() == "opo" {
                    return Item(url: url, type: .object)
                } else if url.pathExtension.lowercased() == "app" {
                    return Item(url: url, type: .application(Self.appInfo(forApplicationUrl: url)))
                } else if url.pathExtension.lowercased() == "sis" {
                    return Item(url: url, type: .installer)
                } else if url.pathExtension.lowercased() == "aif" {
                    return Item(url: url,
                                type: .applicationInformation(OpoInterpreter.shared.getAppInfo(aifPath: url.path)))
                } else if url.pathExtension.lowercased() == "mbm" {
                    return Item(url: url, type: .image)
                } else if url.pathExtension.lowercased() == "snd" {
                    return Item(url: url, type: .sound)
                } else if url.pathExtension.lowercased() == "hlp" {
                    return Item(url: url, type: .help)
                } else if url.pathExtension.lowercased() == "txt" {
                    return Item(url: url, type: .text)
                } else {
                    return Item(url: url, type: .unknown)
                }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) != .orderedDescending }
        return items
    }


    func createDirectory(name: String) throws {
        try FileManager.default.createDirectory(at: url.appendingPathComponent(name),
                                                withIntermediateDirectories: false)
        refresh()
    }

    func delete(_ item: Item) throws {
        try FileManager.default.removeItem(at: item.url)
        refresh()
    }
    
}
