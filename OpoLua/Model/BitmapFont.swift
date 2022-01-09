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

import Foundation
import CoreGraphics
import UIKit

struct BitmapFontInfo {
    let bitmapName: String
    let startIndex: Unicode.Scalar
    let charw: Int
    let charh: Int // aka ascent + descent, same as the "point size" of a TTF font
    let descent: Int

    var ascent: Int {
        return charh - descent
    }

    static let digit = BitmapFontInfo(bitmapName: "digitfont", startIndex: "0", charw: 12, charh: 35, descent: 0)
}

class BitmapFontRenderer {
    let font: BitmapFontInfo
    private let img: CGImage
    let imagew: Int
    let imageh: Int
    var charw: Int { return font.charw }
    var charh: Int { return font.charh }
    var charsPerRow: Int { return imagew / charw }
    var numRows: Int { return imageh / charh }

    init(font: BitmapFontInfo) {
        self.font = font
        self.img = UIImage(named: "fonts/\(font.bitmapName)/\(font.bitmapName)")!.cgImage!
        self.imagew = self.img.width
        self.imageh = self.img.height
    }

    func charInImage(_ char: Character) -> Bool {
        if char.unicodeScalars.count != 1 {
            return false
        }
        let scalarValue = char.unicodeScalars.first!.value
        let maxValue = font.startIndex.value + UInt32(self.charsPerRow * self.numRows)
        return scalarValue >= font.startIndex.value && scalarValue < maxValue
    }

    static func getCharName(_ ch: Character) -> String {
        return ch.unicodeScalars.map({ String(format:"U+%04X", $0.value) }).joined(separator: "_")
    }

    func individualImageForChar(_ char: Character) -> CGImage? {
        let charName = Self.getCharName(char)
        return UIImage(named: "fonts/\(font.bitmapName)/\(charName)")?.cgImage
    }

    func getCharWidth(_ char: Character) -> Int {
        if charInImage(char) {
            // Can't optimise unless it's a character within the image range and the image doesn't require trimming
            return font.charw
        } else {
            if let img = individualImageForChar(char) {
                return img.width
            } else {
                return 0
            }
        }
    }

    func getTextWidth<T>(_ text: T) -> Int where T : StringProtocol {
        var result = 0
        for ch in text {
            result = result + getCharWidth(ch)
        }
        return result
    }

    func getImageForChar(_ char: Character) -> CGImage? {
        if charInImage(char) {
            let charIdx = char.unicodeScalars.first!.value - font.startIndex.value
            let x = Int(charIdx % UInt32(self.charsPerRow))
            // y is counting from the bottom because of stupid coordinate space rubbish
            let y = self.numRows - Int(charIdx / UInt32(self.charsPerRow)) - 1
            let cropped = self.img.cropping(to: CGRect(x: x * charw, y: y * charh, width: charw, height: charh))!
            return cropped
        } else {
            return individualImageForChar(char)
        }
    }
}
