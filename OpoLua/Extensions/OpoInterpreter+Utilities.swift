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

fileprivate let appInfoCache = FileMetadataCache<ApplicationMetadata>()
fileprivate let fileTypeCache = FileMetadataCache<OpoInterpreter.FileType>()

extension OpoInterpreter {

    func cachedAppInfo(forApplicationUrl url: URL) -> ApplicationMetadata? {
        guard let applicationInfoFile = url.applicationInfoUrl,
              FileManager.default.fileExists(atUrl: applicationInfoFile)
        else {
            return nil
        }
        return cachedAppInfo(for: applicationInfoFile)
    }

    func cachedAppInfo(for url: URL) -> ApplicationMetadata? {
        if let applicationInfo = appInfoCache.metadata(for: url) {
            return applicationInfo
        }
        guard let appInfo = appInfo(for: url.path) else {
            return nil
        }
        let applicationInfo = ApplicationMetadata(appInfoUrl: url, appInfo: appInfo)
        appInfoCache.setMetadata(applicationInfo, for: url)
        return applicationInfo
    }

    func cachedRecognize(url: URL) -> FileType {
        if let fileType = fileTypeCache.metadata(for: url) {
            return fileType
        }
        let fileType = recognize(path: url.path)
        fileTypeCache.setMetadata(fileType, for: url)
        return fileType
    }

}
