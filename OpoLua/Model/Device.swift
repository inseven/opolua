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

enum Device: String, CaseIterable, Codable {

    case psionSeries3c = "psion-series-3c"
    case psionSeries5 = "psion-series-5"
    case psionRevo = "psion-revo"
    case psionSeries7 = "psion-series-7"
    case geofoxOne = "geofox-one"

}

extension Device {

    var name: String {
        switch self {
        case .psionSeries3c:
            return "Psion Series 3c"
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
        case .psionSeries3c:
            return Graphics.Size(width:480, height: 160)
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
        case .psionSeries3c:
            return .gray4
        case .psionSeries5:
            return .gray16
        case .psionRevo:
            return .gray16 // Is this right?
        case .psionSeries7:
            return .color256 // ?
        case .geofoxOne:
            return .color256 // ?
        }
    }

    var analogClockImage: CommonImage {
        switch self {
        case .psionSeries3c:
            return .clockMedium()
        case .psionSeries5:
            return .clockMedium()
        case .psionRevo:
            return .clockMedium()
        case .psionSeries7:
            return .clockMediumC()
        case .geofoxOne:
            return .clockMedium()
        }
    }

    static func getDefault(forEra era: PsiLuaEnv.AppEra?) -> Device {
        switch era {
        case .sibo:
            return .psionSeries3c
        case .er5:
            return .psionSeries5
        case .none:
            return .psionSeries5
        }
    }

}
