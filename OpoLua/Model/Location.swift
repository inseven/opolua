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

protocol Location {

    var url: URL { get }

}

protocol SecureLocationProtocol: Location {

    init(url: URL) throws
    init(data: Data) throws
    func dataRepresentation() throws -> Data
    func cleanup() throws

}

class LocalLocation: Location {

    var url: URL

    init(url: URL) {
        self.url = url
    }

}

#if os(macOS)

class ExternalLocation: SecureLocationProtocol {

    let url: URL

    init(url: URL) throws {
        self.url = url
    }

    init(data: Data) throws {
        self.url = try URL(securityScopeBookmarkData: data)
    }

    func dataRepresentation() throws -> Data {
        return try bookmarkData(options: .withSecurityScope,
                                includingResourceValuesForKeys: nil,
                                relativeTo: nil)
    }

    func cleanup() throws {
        // Nothing to do on macOS.
    }

}

#else

class ExternalLocation: SecureLocationProtocol {

    private let backingUrl: URL
    let url: URL

    required init(url: URL) throws {
        self.backingUrl = FileManager.default.secureBookmarksUrl.appendingPathComponent(UUID().uuidString)
        self.url = url
        try FileManager.default.prepareUrlForSecureAccess(url)
    }

    required init(data: Data) throws {
        var isStale = false
        self.backingUrl = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
        self.url = try FileManager.default.readSecureBookmark(url: backingUrl)
    }

    func dataRepresentation() throws -> Data {
        let fileManager = FileManager.default
        let secureBookmarksUrl = fileManager.secureBookmarksUrl
        if !fileManager.directoryExists(atPath: secureBookmarksUrl.path) {
            try fileManager.createDirectory(at: secureBookmarksUrl, withIntermediateDirectories: true, attributes: nil)
        }
        try FileManager.default.writeSecureBookmark(url, to: backingUrl)
        return try backingUrl.bookmarkData(options: [.minimalBookmark],
                                           includingResourceValuesForKeys: nil,
                                           relativeTo: nil)
    }

    func cleanup() throws {
        try FileManager.default.removeItem(at: backingUrl)
    }

}

#endif

extension UserDefaults {

    func secureLocations(forKey defaultName: String) throws -> [ExternalLocation] {
        guard let urls = UserDefaults.standard.array(forKey: defaultName) as? [Data] else {
            print("Failed to load security scoped URLs for '\(defaultName)'.")
            return []
        }
        return try urls.map { try ExternalLocation(data: $0) }
    }

    func set(secureLocations: [ExternalLocation], forKey defaultName: String) throws {
        let bookmarks = try secureLocations.map { try $0.dataRepresentation() }
        UserDefaults.standard.set(bookmarks, forKey: defaultName);
    }

}
