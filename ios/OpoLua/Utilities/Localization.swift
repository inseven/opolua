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

import OpoLuaCore

extension Graphics.Bitmap.Mode {

    var localizedDescription: String {
        switch self {
        case .gray2:
            return "Gray, 1BPP"
        case .gray4:
            return "Gray, 2BPP"
        case .gray16:
            return "Gray, 4BPP"
        case .gray256:
            return "Gray, 8BPP"
        case .color16:
            return "Color, 4BPP"
        case .color256:
            return "Color, 8BPP"
        case .color64K:
            return "Color, 16BPP"
        case .color16M:
            return "Color, 24BPP"
        case .colorRGB:
            return "Color, 32BPP"
        case .color4K:
            return "Color, 12BPP"
        }
    }

}

extension Settings.Theme {

    var localizedDescription: String {
        switch self {
        case .series5:
            return "Series 5"
        case .series7:
            return "Series 7"
        }
    }

}
