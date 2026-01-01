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

import Foundation
import OplCore

public typealias OplKeyCode = OplCore.OplKeyCode

// I'm not sure why bridged C enums (with __attribute__((enum_extensibility(closed))) are exposed as UInt32
protocol Int32Representable<RawValue> : RawRepresentable where RawValue == UInt32 {
    var int32Value: Int32 { get }
}

extension Int32Representable {
    var int32Value: Int32 {
        return Int32(self.rawValue)
    }
}

protocol IntRepresentable<RawValue> : RawRepresentable where RawValue == UInt32 {
    var intValue: Int { get }
}

extension IntRepresentable {
    var intValue: Int {
        return Int(self.rawValue)
    }
}

extension OplKeyCode : Int32Representable {}

extension OplKeyCode {

    public static func from(string: String) -> OplKeyCode? {
        if string.count != 1 {
            return nil // UIKey.characters can return some _actual text descriptions_ of keys!
        }
        let ch = string.unicodeScalars.first!
        let result = oplUnicodeToKeycode(ch.value)
        if result == 0 {
            return nil
        } else {
            return OplKeyCode(rawValue: UInt32(result))!
        }
    }

    func toScancode(sibo: Bool) -> Int {
        let result = oplScancodeForKeycode(self.int32Value, sibo)
        return Int(result)

    }

    // Returns nil for things without a charcode (like modifier keys)
    public func toCharcode() -> Int? {
        let result = oplCharcodeForKeycode(self.int32Value)
        if result == 0 {
            return nil
        } else {
            return Int(result)
        }
    }

    public func modifiedKeycode(_ modifiers: Modifiers) -> Int? {
        let result = oplModifiedKeycode(self.int32Value, UInt32(modifiers.rawValue))
        if result == 0 {
            return nil
        } else {
            return Int(result)
        }
    }
}

extension EventId : IntRepresentable {}

extension TEventModifiers : IntRepresentable {}

public typealias PointerType = OplCore.PointerType
extension PointerType : IntRepresentable {}
