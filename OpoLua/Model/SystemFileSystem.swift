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

class SystemFileSystem: FileSystem {

    var rootUrl: URL

    init(rootUrl: URL) {
        self.rootUrl = rootUrl
    }

    func hostUrl(for path: String) -> URL? {
        let components = path.split(separator: "\\")
            .map { String($0) }
        guard let drive = components.first else {
            return nil
        }
        let driveLetter = String(drive.prefix(1))
        let normalizedComponents = [driveLetter] + Array(components[1...])
        let hostUrl = rootUrl.appendingCaseInsensitivePathComponents(normalizedComponents)
        return hostUrl
    }

    func guestPath(for url: URL) -> String? {
        let relativePath = url.relativePath(from: rootUrl)
        let components = relativePath.split(separator: "/")
            .map { String($0) }
        guard let driveLetter = components.first else {
            return nil
        }
        let result = driveLetter + ":\\" + components[1...].joined(separator: "\\")
        return result
    }

}