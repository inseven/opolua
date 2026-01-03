// Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe
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

import OpoLuaCore
import OplCore

typealias Device = OplCore.OplDeviceType

// OplDeviceType is declared as a closed enum so I don't know why it can't be made CaseIterable
extension Device: @retroactive CaseIterable {

    public static var allCases: [OplDeviceType] {
        return [
            .psionSeries3,
            .psionSeries3c,
            .psionSiena,
            .psionSeries5,
            .psionRevo,
            .psionSeries7,
            .geofoxOne
        ]
    }

}

extension Device: @retroactive Codable {

    public init(from decoder: any Decoder) throws {
        let identifier = try decoder.singleValueContainer().decode(String.self)
        let device = oplGetDeviceFromName(identifier)
        if device == -1 {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "string is not a known device"))
        }
        self.init(rawValue: UInt32(device))!
    }

    public func encode(to encoder: any Encoder) throws {
        try self.identifier.encode(to: encoder)
    }
}

extension Device {

    var identifier: String {
        return String(cString: oplGetDeviceName(self))
    }

    var name: String {
        switch self {
        case .psionSeries3:
            return "Psion Series 3"
        case .psionSeries3c:
            return "Psion Series 3c"
        case .psionSiena:
            return "Psion Siena"
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
        var w: CInt = 0
        var h: CInt = 0
        oplGetScreenSize(self, &w, &h)
        return Graphics.Size(width: Int(w), height: Int(h))
    }

    var screenMode: Graphics.Bitmap.Mode {
        return .init(rawValue: Int(oplGetScreenMode(self)))!
    }

    var analogClockImage: CommonImage {
        switch self {
        case .psionSeries3:
            return .clockMedium()
        case .psionSeries3c:
            return .clockMedium()
        case .psionSiena:
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

    var isSibo: Bool {
        return oplIsSiboDevice(self)
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
