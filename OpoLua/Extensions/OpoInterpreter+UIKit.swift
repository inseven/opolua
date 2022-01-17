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

extension Graphics.Size {

    func greater(than size: Graphics.Size) -> Bool {
        return width > size.width && height > size.height
    }

    func less(thanOrEqualTo size: Graphics.Size) -> Bool {
        return width <= size.width && height <= size.height
    }

}

extension OpoInterpreter.AppInfo {

    // TODO: Let this accept a size.
    var appIcon: UIImage? {
        print("Icons for \(caption):")
        var bitmap: Graphics.MaskedBitmap? = nil
        for icon in icons {
            print("\(icon.bitmap.size)")
            // Skip bitmaps that are too large.
            guard icon.bitmap.size.less(thanOrEqualTo: Graphics.Size.icon) else {
                print("Ignoring large bitmap")
                continue
            }
            guard let currentBitmap = bitmap else {
                print("Selecting as initial candidate")
                bitmap = icon
                continue
            }
            if icon.bitmap.size.greater(than: currentBitmap.bitmap.size) {
                print("Selecting as candidate")
                bitmap = icon
            }
        }
        guard let bitmap = bitmap else {
            return nil
        }
        if let cgImg = bitmap.cgImage {
            return UIImage(cgImage: cgImg)
        }
        return nil
    }

}
