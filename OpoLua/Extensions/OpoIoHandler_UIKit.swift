// Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe
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

#if os(iOS)

import UIKit

import OpoLuaCore

 extension Graphics.FontInfo {
     func toUiFont() -> UIFont? {
         let sz = CGFloat(self.size)
         let uiFontName: String
         var traits: UIFontDescriptor.SymbolicTraits = []
         if self.flags.contains(.bold) || self.flags.contains(.boldHint) {
             traits.insert(.traitBold)
         }
         switch self.face {
         case .arial:
             uiFontName = "Arial"
         case .times:
             uiFontName = "Times"
         case .courier:
             uiFontName = "Courier"
         case .tiny:
             uiFontName = "Courier" // Who knows...
         case .squashed:
             uiFontName = "Helvetica Neue"
             traits.insert(.traitCondensed)
         case .digit, .eiksym:
             return nil
         }

         var desc = UIFontDescriptor(name: uiFontName, size: sz)
         if let newDesc = desc.withSymbolicTraits(traits) {
             desc = newDesc
         }
         return UIFont(descriptor: desc, size: sz)
     }

     func toBitmapFont() -> BitmapFontInfo? {
         return BitmapFontInfo(uid: self.uid)
     }
 }

#endif
