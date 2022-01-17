// Copyright (c) 2021-2022 Jason Morley, Tom Sutcliffe
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

extension OpoInterpreter.AppInfo {

    func image(for size: Graphics.Size) -> UIImage? {
        var bitmap: Graphics.MaskedBitmap? = nil
        for icon in icons {
            guard icon.bitmap.size <= size && icon.bitmap.size == icon.mask?.size else {
                continue
            }
            guard let currentBitmap = bitmap else {
                bitmap = icon
                continue
            }
            if icon.bitmap.size > currentBitmap.bitmap.size {
                bitmap = icon
            }
        }
        guard let bitmap = bitmap else {
            print("Failed to find icon for '\(self.caption)'.")
            for icon in icons {
                print("  bitmap = \(icon.bitmap.size), mask = \(icon.mask!.size)")
            }
            return nil
        }
        if let cgImg = bitmap.cgImage {
            return UIImage(cgImage: cgImg)
        }
        return nil
    }

}
