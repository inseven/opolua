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

extension FileManager {

    func directoryExists(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        if fileExists(atPath: path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        return false
    }

    func fileExists(atUrl url: URL) -> Bool {
        guard url.isFileURL else {
            return false
        }
        return fileExists(atPath: url.path)
    }

    var documentsUrl: URL {
        return urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var secureBookmarksUrl: URL {
        return documentsUrl.appendingPathComponent("SecureBookmarks")
    }

    func prepareUrlForSecureAccess(_ url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw ApplicationError.accessDenied
        }
        guard isReadableFile(atPath: url.path) else {
            throw ApplicationError.accessDenied
        }
    }

    func writeSecureBookmark(_ url: URL, to backingUrl: URL) throws {
        try prepareUrlForSecureAccess(url)
        let data = try url.bookmarkData(options: .suitableForBookmarkFile,
                                        includingResourceValuesForKeys: nil,
                                        relativeTo: nil)
        try URL.writeBookmarkData(data, to: backingUrl)
    }

    func readSecureBookmark(url: URL) throws -> URL {
        let bookmarkData = try URL.bookmarkData(withContentsOf: url)
        var isStale: Bool = true
        let url = try URL(resolvingBookmarkData: bookmarkData,
                          options: [],
                          relativeTo: nil,
                          bookmarkDataIsStale: &isStale)
        try prepareUrlForSecureAccess(url)
        return url
    }

    func findCorrectCase(in path: URL, for uncasedName: String) throws -> String {
        if fileExists(atUrl: path.appendingPathComponent(uncasedName)) {
            // No need to check anything else
            return uncasedName
        }
        let contents = try contentsOfDirectory(at: path, includingPropertiesForKeys: [])
        let uppercasedName = uncasedName.uppercased()
        for url in contents {
            let name = url.lastPathComponent
            if name.uppercased() == uppercasedName {
                return name
            }
        }
        // If the requested name ends in a dot, also see if there's an undotted
        // name because epoc seems to have a weird way of dealing with
        // extensionless names
        if uncasedName.hasSuffix(".") {
            // This does not seem to me to be more elegant than having a simple substring API...
            let ugh = uncasedName.lastIndex(of: ".")!
            let unsuffixedName = uncasedName[..<ugh].uppercased()
            for url in contents {
                let name = url.lastPathComponent
                if name.uppercased() == unsuffixedName {
                    return name
                }
            }
        }
        if let dot = uncasedName.lastIndex(of: ".") {
            let suff = uncasedName[uncasedName.index(after: dot)...]
            if suff.count > 3 {
                //  Try truncating the extension to 3 chars
                let newName = String(uncasedName[...dot]) + suff.prefix(3)
                return try findCorrectCase(in: path, for: newName)
            }
        }
        return uncasedName
    }


}
