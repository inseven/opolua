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

import UIKit

extension UIKey {

    func oplKeyCode() -> KeyCode? {
        switch self.keyCode {
        case .keyboardUpArrow: return .upArrow
        case .keyboardDownArrow: return .downArrow
        case .keyboardLeftArrow: return .leftArrow
        case .keyboardRightArrow: return .rightArrow
        case .keyboardReturnOrEnter: return .enter
        case .keyboardLeftShift: return .leftShift
        case .keyboardRightShift: return .rightShift
        case .keyboardLeftControl: return .control
        default:
            return nil
        }
    }

    func oplModifiers() -> Modifiers {
        let flags = self.modifierFlags
        var result = Modifiers()
        if flags.contains(.shift) {
            result.insert(.shift)
        }
        if flags.contains(.control) {
            result.insert(.control)
        }
        if flags.contains(.alphaShift) {
            result.insert(.capsLock)
        }
        return result
    }
}
