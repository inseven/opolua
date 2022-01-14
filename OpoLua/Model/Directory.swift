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

class Directory {

    struct Application {

        let url: URL
        let appInfo: OpoInterpreter.AppInfo

        init(url: URL, appInfo: OpoInterpreter.AppInfo) {
            self.url = url
            self.appInfo = appInfo
        }

        init(url: URL) {
            guard url.isApplication,
                  let applicationInfoFile = url.applicationInfoFile,
                  FileManager.default.fileExists(atUrl: applicationInfoFile),
                  let appInfo = OpoInterpreter.shared.getAppInfo(aifPath: applicationInfoFile.path)
            else {
                self.url = url
                self.appInfo = OpoInterpreter.AppInfo(caption: url.name, uid3: 0, icons: [])
                return
            }
            self.url = url
            self.appInfo = appInfo
        }

    }

    struct Item {

        enum `Type` {
            case object
            case directory
            case app
            case bundle(Application)
            case system(Application)
            case installer

            var localizedDescription: String {
                switch self {
                case .object:
                    return "Object"
                case .directory:
                    return "Directory"
                case .app:
                    return "Application"
                case .bundle:
                    return "Bundle"
                case .system:
                    return "System"
                case .installer:
                    return "Installer"
                }
            }
        }

        let url: URL
        let type: `Type`

        var name: String {
            switch type {
            case .bundle(let application):
                return application.appInfo.caption
            default:
                return url.name
            }
        }

        var configuration: Program.Configuration? {
            switch type {
            case .bundle(let application):
                return Program.Configuration(url: application.url)
            case .system(let application):
                return Program.Configuration(url: application.url)
            default:
                return Program.Configuration(url: url)
            }
        }

        var icon: UIImage {
            switch type {
            case .object:
                return .oplIcon
            case .directory:
                return .folderIcon
            case .app:
                return .unknownAppIcon
            case .bundle(let application):
                if let appIcon = application.appInfo.appIcon {
                    return appIcon
                } else {
                    return .unknownAppIcon
                }
            case .system(let application):
                if let appIcon = application.appInfo.appIcon {
                    return appIcon
                } else {
                    return .unknownAppIcon
                }
            case .installer:
                return .sisIcon
            }
        }

    }

    private static func asSystem(url: URL) throws -> Item.`Type`? {
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
            .compactMap { Application(url: $0) }

        // TODO: Allow systems containing more than one app.
        guard apps.count == 1,
              let application = apps.first else {
            return nil
        }
        return .system(application)
    }

    private static func asBundle(url: URL) throws -> Item.`Type`? {

        let apps = try url.contents
            .filter { $0.isApplication }
            .compactMap { Application(url: $0) }

        // TODO: Allow bundles containing more than one app.
        guard apps.count == 1,
              let application = apps.first else {
            return nil
        }

        return .bundle(application)
    }

    let url: URL
    var items: [Item] = []

    weak var delegate: DirectoryDelegate?

    var name: String {
        return url.name
    }
    
    init(url: URL) throws {
        self.url = url
        try self.refresh()
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

    func refresh() throws {
        items = try url.contents
            .filter { !$0.lastPathComponent.starts(with: ".") }
            .compactMap { url -> Item? in
                if FileManager.default.directoryExists(atPath: url.path) {
                    // Check for an app 'bundle'.
                    if let type = try Self.asSystem(url: url) {
                        return Item(url: url, type: type)
                    } else if let type = try Self.asBundle(url: url) {
                        return Item(url: url, type: type)
                    } else {
                        return Item(url: url, type: .directory)
                    }
                } else if url.pathExtension.lowercased() == "opo" {
                    return Item(url: url, type: .object)
                } else if url.pathExtension.lowercased() == "app" {
                    return Item(url: url, type: .app)
                } else if url.pathExtension.lowercased() == "sis" {
                    return Item(url: url, type: .installer)
                } else {
                    return nil
                }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) != .orderedDescending }
        delegate?.directoryDidChange(self)
    }

    func createDirectory(name: String) throws {
        try FileManager.default.createDirectory(at: url.appendingPathComponent(name),
                                                withIntermediateDirectories: false)
        try refresh()
    }

    func delete(_ item: Item) throws {
        try FileManager.default.removeItem(at: item.url)
        try refresh()
    }
    
}
