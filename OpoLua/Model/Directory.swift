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

class Directory {

    struct Item {

        enum `Type` {
            case object
            case directory
            case app
        }

        let url: URL
        let type: `Type`

        var name: String {
            return url.name
        }

    }

    let url: URL
    let objects: [Item]

    var name: String {
        return url.name
    }
    
    init(url: URL) throws {
        self.url = url
        objects = try FileManager.default.contentsOfDirectory(atPath: url.path)
            .map { url.appendingPathComponent($0) }
            .filter { !$0.lastPathComponent.starts(with: ".") }
            .compactMap { url -> Item? in
                if FileManager.default.directoryExists(atPath: url.path) {
                    return Item(url: url, type: .directory)
                } else if url.pathExtension == "opo" {
                    return Item(url: url, type: .object)
                } else if url.pathExtension == "app" {
                    return Item(url: url, type: .app)
                } else {
                    return nil
                }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) != .orderedDescending }
    }
    
}
