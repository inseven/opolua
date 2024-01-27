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

class FileMetadataCache<T> {

    private class CacheKey: NSObject {

        let url: URL
        let modificationDate: Date

        init(url: URL, modificationDate: Date) {
            self.url = url
            self.modificationDate = modificationDate
        }

        override var hash: Int {
            return url.hashValue | modificationDate.hashValue
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let object = object as? CacheKey else {
                return false
            }
            return url == object.url && modificationDate == object.modificationDate
        }

    }

    private class CacheItem {

        let item: T

        init(item: T) {
            self.item = item
        }

    }

    static private func cacheKey(for url: URL) -> FileMetadataCache.CacheKey? {
        guard let modificationDate = url.modificationDate() else {
            return nil
        }
        return FileMetadataCache.CacheKey(url: url, modificationDate: modificationDate)
    }

    private let cache = NSCache<CacheKey, CacheItem>()

    func metadata(for url: URL) -> T? {
        guard let key = Self.cacheKey(for: url) else {
            return nil
        }
        return cache.object(forKey: key)?.item
    }

    func setMetadata(_ metadata: T, for url: URL) {
        guard let key = Self.cacheKey(for: url) else {
            return
        }
        cache.setObject(CacheItem(item: metadata), forKey: key)
    }

}
