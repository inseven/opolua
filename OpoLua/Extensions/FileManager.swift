// Copyright (c) 2021-2023 Jason Morley, Tom Sutcliffe
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

    var applicationSupportUrl: URL {
        return urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    var secureBookmarksUrl: URL {
        return applicationSupportUrl.appendingPathComponent("SecureBookmarks")
    }

    func prepareUrlForSecureAccess(_ url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw ApplicationError.accessDenied
        }
        guard isReadableFile(atPath: url.path) else {
            throw ApplicationError.accessDenied
        }
    }

    func startDownloadingUbitquitousItemsRecursive(for url: URL) {
        var ubiquitousItems: [URL] = []

        // There are quite a few ugly things going on here which are workarounds for `NSMetadataQuery` not seeming to
        // work as documented. I'd like to think I'm using it incorrectly, but until I figure out exactly _how_ I'm
        // holding it wrong, there are some things to be aware of:

        // 1) Only `enumerator` will show us the hidden iCloud Drive files.
        var urls = [url]
        while let url = urls.popLast() {
            let contentsEnumerator = enumerator(at: url.resolvingSymlinksInPath(),
                                                includingPropertiesForKeys: [],
                                                options: [])
            while let url = contentsEnumerator?.nextObject() as? URL {

                // 1a) Unfortunately the enumerator won't actually resovle symlinks on our behalf, so we detect and
                //     resolve them, then add then add any directories to the queue of URLs to explore.
                let resourceValues = try! url.resourceValues(forKeys: [.isSymbolicLinkKey])
                if resourceValues.isSymbolicLink! {
                    let resolvedUrl = url.resolvingSymlinksInPath()
                    if resolvedUrl.isDirectory {
                        urls.insert(resolvedUrl, at: 0)
                    }
                    continue
                }

                // 2) Unfortunately `isUbiquitousItem(at:)` doesn't report any of these files as ubiquitous items (aka.
                //    iCloud Drive items), so we instead have to look for files ending in the .icloud extension.
                if url.pathExtension.lowercased() == "icloud" {
                    ubiquitousItems.append(url)
                }
            }
        }

        // 2a) Don't bother doing anything else if there are no new items to download.
        guard ubiquitousItems.count > 0 else {
            return
        }
        print("Scheduling download for \(ubiquitousItems.count) ubiquitous items...")

        // 3) Files with the .icloud extension seem to appear before the system has fully registered the presence of the
        //    iCloud Drive item and calling `startDownloadingUbiquitousItem` immediately will fail. This can happen if
        //    we're being called in response to a file system change event. We therefore introduce some artificial delay
        //    before requesting a download (2 seconds). We make sure we request the download on the main thread because
        //    some things in the iCloud world seem to fail silently when run elsewhere. 🤦🏻‍♂️
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            for url in ubiquitousItems {
                guard self.fileExists(atUrl: url) else {
                    continue
                }
                do {
                    try self.startDownloadingUbiquitousItem(at: url)
                } catch {
                    print("Failed to start iCloud download for '\(url)' with error \(error).")
                }
            }
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

    func isSystem(at url: URL) throws -> Bool {
        guard url.lastPathComponent.hasSuffix(".system") else {
            return false
        }

        let contents = try contentsOfDirectory(atPath: url.path).map { url.appendingPathComponent($0) }
        let drives: Set<String> = ["c", "m"]

        // Ensure there only folders named for valid drive letters present.
        // N.B. This implementation is intetnionally strict. We can relax it as and when we find we need to.
        for url in contents {
            let name = url.lastPathComponent
            if name.starts(with: ".") {
                // Ignore hidden files.
                continue
            }
            guard url.isDirectory,
                  drives.contains(name.lowercased())
            else {
                return false
            }
        }
        return true
    }

    func detectSystemFileSystem(for url: URL) throws -> FileSystem? {
        // Helpfully `deletingLastPathComponent` starts adding `..` components to the path making it quite hard to
        // detect that we've run out of path. We therefore explicitly check for root.
        guard url.path != "/" else {
            return nil
        }
        let parentUrl = url.deletingLastPathComponent()
        if try isSystem(at: parentUrl) {
            return SystemFileSystem(rootUrl: parentUrl)
        }
        return try detectSystemFileSystem(for: parentUrl)
    }

}
