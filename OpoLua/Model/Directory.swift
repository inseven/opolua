// Copyright (c) 2021 Jason Morley, Tom Sutcliffe
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

class Directory {

    struct Application {

        let url: URL
        let appInfo: OpoInterpreter.AppInfo

        init(url: URL, appInfo: OpoInterpreter.AppInfo) {
            self.url = url
            self.appInfo = appInfo
        }

        init?(url: URL) {
            guard url.isApplication,
                  let applicationInfoFile = url.applicationInfoFile,
                  FileManager.default.fileExists(atUrl: applicationInfoFile),
                  let appInfo = OpoInterpreter.shared.getAppInfo(aifPath: applicationInfoFile.path)
            else {
                return nil
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

        var object: OPLObject {
            switch type {
            case .bundle(let application):
                return OPLObject(url: application.url)
            case .system(let application):
                return OPLObject(url: application.url)
            default:
                return OPLObject(url: url)
            }
        }

    }

    let url: URL
    let objects: [Item]

    var name: String {
        return url.name
    }

    static func asSystem(url: URL) throws -> Item.`Type`? {

        let contents = try url.contents
        let drives: Set<String> = ["c", "C"]

        // Ensure there only folders named for valid drive letters present.
        // N.B. This implementation is intetnionally strict. We can relax it as and when we find we need to.
        for url in contents {
            let name = url.lastPathComponent
            if name.starts(with: ".") {
                // Ignore hidden files.
                continue
            }
            guard url.isDirectory,
                  drives.contains(name)
            else {
                return nil
            }
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

    static func asBundle(url: URL) throws -> Item.`Type`? {

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
    
    init(url: URL) throws {
        self.url = url
        objects = try url.contents
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
                } else if url.pathExtension == "opo" {
                    return Item(url: url, type: .object)
                } else if url.pathExtension == "app" {
                    return Item(url: url, type: .app)
                } else {
                    return nil
                }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) != .orderedDescending }
    }
    
}
