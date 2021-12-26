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

class ObjectFileSystem: FileSystem {

    var baseUrl: URL
    var name: String

    /**
     This file system mapper simulates a C:\System\Apps\<app name>\ path.
     */
    init(objectUrl: URL) {
        self.baseUrl = objectUrl.deletingLastPathComponent()
        self.name = objectUrl.basename
    }

    var guestPrefix: String {
        return "C:\\SYSTEM\\APPS\\" + name.uppercased() + "\\"
    }

    func hostUrl(for path: String) -> URL? {
        if path.uppercased().starts(with: guestPrefix) {
            let pathComponents = path.split(separator: "\\")[4...]
            var result = baseUrl
            for component in pathComponents {
                if component == "." || component == ".." {
                    continue
                }
                // Have to do some nasty hacks here to appear case-insensitive
                let name = (try? FileManager.default.findCorrectCase(in: result, for: String(component))) ?? String(component)
                result.appendPathComponent(name)
            }
            print(result.absoluteURL)
            return result.absoluteURL
        } else {
            return nil
        }
    }

    func guestPath(for url: URL) -> String? {
        guard url.path.hasPrefix(baseUrl.path) else {
            return nil
        }
        let relativePath = String(url.absoluteString.dropFirst(baseUrl.absoluteString.count))
        return guestPrefix + relativePath.pathComponents.joined(separator: "\\")
    }

}
