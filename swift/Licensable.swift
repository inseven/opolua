// Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe
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

import Licensable

extension Licensable where Self == License {

    public static var lua: License {
        let licenseURL = Bundle.module.url(forResource: "lua-license", withExtension: nil)!
        return License(id: "https://www.lua.org",
                       name: "Lua",
                       author: "Lua.org, PUC-Rio",
                       text: try! String(contentsOf: licenseURL),
                       attributes: [],
                       licenses: [])
    }

    public static var opolua: License {
        let licenseURL = Bundle.module.url(forResource: "opolua-license", withExtension: nil)!
        return License(id: "https://github.com/inseven/opolua",
                       name: "OpoLua",
                       author: "Jason Morley, Tom Sutcliffe",
                       text: try! String(contentsOf: licenseURL),
                       attributes: [
                        .url(URL(string: "https://opolua.org")!, title: "Website"),
                        .url(URL(string: "https://github.com/inseven/opolua")!, title: "GitHub"),
                       ],
                       licenses: [.lua])
    }

}
