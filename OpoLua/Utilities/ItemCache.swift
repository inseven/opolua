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

class ItemCache {

    fileprivate class CacheKey: NSObject {

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

    fileprivate class CacheItem {

        let item: Directory.Item

        init(item: Directory.Item) {
            self.item = item
        }

    }

    private let cache = NSCache<CacheKey, CacheItem>()

    func item(for url: URL) -> Directory.Item? {
        guard let key = url.cacheKey() else {
            return nil
        }
        return cache.object(forKey: key)?.item
    }

    func setItem(_ item: Directory.Item, for url: URL) {
        guard let key = url.cacheKey() else {
            return
        }
        cache.setObject(CacheItem(item: item), forKey: key)
    }

}

extension URL {

    fileprivate func cacheKey() -> ItemCache.CacheKey? {
        guard let modificationDate = modificationDate() else {
            return nil
        }
        return ItemCache.CacheKey(url: self, modificationDate: modificationDate)
    }

}
