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


extension Settings.Theme {

    var folderIcon: UIImage {
        switch self {
        case .series5:
            return .folderIcon
        case .series7:
            return .folderIconC
        }
    }

    var installerIcon: UIImage {
        switch self {
        case .series5:
            return .installerIcon
        case .series7:
            return .installerIconC
        }
    }

    var opoIcon: UIImage {
        switch self {
        case .series5:
            return .opoIcon
        case .series7:
            return .opoIconC
        }
    }

    var unknownFileIcon: UIImage {
        switch self {
        case .series5:
            return .unknownAppIcon
        case .series7:
            return .unknownFileIconC
        }
    }

}


class Directory {

    struct Application {

        let url: URL
        let appInfo: OpoInterpreter.AppInfo?

        init(url: URL) {
            self.url = url
            self.appInfo = Directory.appInfo(forApplicationUrl: url)
        }

    }

    static func appInfo(forApplicationUrl url: URL) -> OpoInterpreter.AppInfo? {
        guard let applicationInfoFile = url.applicationInfoFile,
              FileManager.default.fileExists(atUrl: applicationInfoFile)
        else {
            return nil
        }
        return OpoInterpreter.shared.getAppInfo(aifPath: applicationInfoFile.path)
    }

    struct Item {

        enum `Type` {
            case object
            case directory
            case application(OpoInterpreter.AppInfo?)
            case system(Application)
            case installer
            case applicationInformation(OpoInterpreter.AppInfo?)
            case unknown

            var localizedDescription: String {
                switch self {
                case .object:
                    return "Object"
                case .directory:
                    return "Directory"
                case .application:
                    return "Application"
                case .system:
                    return "System"
                case .installer:
                    return "Installer"
                case .applicationInformation:
                    return "App Info"
                case .unknown:
                    return "Unknown"
                }
            }
        }

        let url: URL
        let type: `Type`

        var name: String {
            switch type {
            case .system(let application):
                return application.appInfo?.caption ?? url.lastPathComponent
            default:
                return url.lastPathComponent
            }
        }

        func icon(for theme: Settings.Theme) -> UIImage {
            switch type {
            case .object:
                return theme.opoIcon
            case .directory:
                return theme.folderIcon
            case .application(let appInfo):
                return appInfo?.appIcon ?? .unknownAppIcon
            case .system(let application):
                if let appIcon = application.appInfo?.appIcon {
                    return appIcon
                } else {
                    return .unknownAppIcon
                }
            case .installer:
                return theme.installerIcon
            case .applicationInformation(let appInfo):
                return appInfo?.appIcon ?? .unknownAppIcon
            case .unknown:
                return theme.unknownFileIcon
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
            case .system(let application):
                return application.url
            case .installer:
                return nil
            case .applicationInformation:
                return nil
            case .unknown:
                return nil
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

        guard apps.count == 1,
              let application = apps.first else {
            return nil
        }
        return .system(application)
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
                } else {
                    return Item(url: url, type: .unknown)
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
