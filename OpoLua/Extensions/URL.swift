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

extension URL {

    private static func description(details: String, title: String, sourceUrl: URL?) -> String {
        return """
## Description

_Please provide details of the program you were running, and what you were doing when you encountered the error._

## Metadata

| Key | Value |
| --- | --- |
| **Title** | \(title) |
| **Source URL** | \(sourceUrl?.absoluteString ?? "*unknown*") |

## Details

```
\(details)
```
"""
    }

    private static func gitHubIssueURL(title: String, description: String, labels: [String]) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = "/inseven/opolua/issues/new"
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: description),
            URLQueryItem(name: "labels", value: labels.joined(separator: ",")),
        ]
        return components.url
    }

    static func gitHubIssueURL(for error: Error, title: String, sourceUrl: URL?) -> URL? {
        if let _ = error as? OpoInterpreter.LeaveError {
            return nil
        } else if let _ = error as? OpoInterpreter.NativeBinaryError {
            return nil
        } else if let unimplementedOperation = error as? OpoInterpreter.UnimplementedOperationError {
            let description = description(details: unimplementedOperation.detail, title: title, sourceUrl: sourceUrl)
            return URL.gitHubIssueURL(title: "[\(title)] Unimplemented Operation: \(unimplementedOperation.operation)",
                                   description: description,
                                   labels: ["facerake", "bug"])
        } else if let interpreterError = error as? OpoInterpreter.InterpreterError {
            let description = description(details: interpreterError.detail, title: title, sourceUrl: sourceUrl)
            return URL.gitHubIssueURL(title: "[\(title)] Internal Error: \(interpreterError.message)",
                                   description: description,
                                   labels: ["internal-error", "bug"])
        }
        return nil
    }

    var localizedName: String {
        if self == FileManager.default.documentsUrl {
            return UIDevice.current.localizedDocumentsName
        }
        return FileManager.default.displayName(atPath: path)
    }

    var components: URLComponents? { return URLComponents(string: absoluteString) }

    var isDirectory: Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    var deletingPathExtension: URL? {
        guard var components = components else {
            return nil
        }
        components.path = components.path.deletingPathExtension
        return components.url
    }

    func appendingPathExtension(_ str: String) -> URL? {
        guard var components = components,
              let path = components.path.appendingPathExtension(str)
        else {
            return nil
        }
        components.path = path
        return components.url
    }

    var applicationInfoUrl: URL? {
        return deletingLastPathComponent().appendingCaseInsensitivePathComponents([basename.appendingPathExtension("aif")!])
    }

    var programConfigurationUrl: URL {
        return deletingLastPathComponent().appendingPathComponent((basename + "-configuration").appendingPathExtension("json")!)
    }

    var isApplication: Bool {
        let ext = path.pathExtension.lowercased()
        return ext == "app" || ext == "opa"
    }

    var basename: String {
        return self.path.basename
    }

    func appendingCaseInsensitivePathComponents(_ components: [String]) -> URL {
        var result = self
        for component in components {
            if component == "." || component == ".." {
                continue
            }
            let name = (try? FileManager.default.findCorrectCase(in: result, for: component)) ?? component
            result.appendPathComponent(name)
        }
        return result.absoluteURL
    }

    func relativePath(from url: URL) -> String {
        assert(self.isFileURL)
        let destination = resolvingSymlinksInPath()
        let source = url.resolvingSymlinksInPath()
        assert(destination.path.hasPrefix(source.path))
        return String(destination.path.dropFirst(source.path.count))
    }

    func prepareForSecureAccess() throws {
        guard startAccessingSecurityScopedResource() else {
            throw OpoLuaError.secureAccess
        }
        guard FileManager.default.isReadableFile(atPath: path) else {
            throw OpoLuaError.secureAccess
        }
    }

    func ubiquitousItemDownloadingStatus() throws -> URLUbiquitousItemDownloadingStatus {
        dispatchPrecondition(condition: .onQueue(.main)) // Returns garbage if it's not on main. 🤦🏻‍♂️
        var value: AnyObject? = nil
        try (self as NSURL).getResourceValue(&value, forKey: .ubiquitousItemDownloadingStatusKey)
        guard let status = value as? URLUbiquitousItemDownloadingStatus else {
            return URLUbiquitousItemDownloadingStatus.notDownloaded
        }
        return status
    }

    func modificationDate() -> Date? {
        guard isFileURL else {
            return nil
        }
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: path)
            return attr[FileAttributeKey.modificationDate] as? Date
        } catch {
            return nil
        }
    }

}
