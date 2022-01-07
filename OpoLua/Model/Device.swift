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

enum Device: CaseIterable {

    case psionSeries5
    case psionRevo
    case psionSeries7
    case geofoxOne

}

extension Device {

    var name: String {
        switch self {
        case .psionSeries5:
            return "Psion Series 5"
        case .psionRevo:
            return "Psion Revo"
        case .psionSeries7:
            return "Psion Series 7"
        case .geofoxOne:
            return "Geofox One"
        }
    }

    var screenSize: Graphics.Size {
        switch self {
        case .psionSeries5:
            return Graphics.Size(width:640, height: 240)
        case .psionRevo:
            return Graphics.Size(width: 480, height: 160)
        case .psionSeries7:
            return Graphics.Size(width:640, height: 480)
        case .geofoxOne:
            return Graphics.Size(width: 640, height: 320)
        }
    }

    var screenMode: Graphics.Bitmap.Mode {
        switch self {
        case .psionSeries5:
            return .Gray16
        case .psionRevo:
            return .Gray16 // Is this right?
        case .psionSeries7:
            return .Color256 // ?
        case .geofoxOne:
            return .Color256 // ?
        }
    }

}
