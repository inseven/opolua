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

extension FileManager {

    func directoryExists(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        if fileExists(atPath: path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        return false
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

}
