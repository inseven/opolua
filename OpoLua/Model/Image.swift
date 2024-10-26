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

#if canImport(UIKit)

import UIKit
typealias Image = UIImage
typealias ImageView = UIImageView

#else

import AppKit
typealias Image = NSImage
typealias ImageView = NSImageView

// Some helpers to make it look more like the UIImage API
extension NSImage {

    public convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: .zero)
    }

    public func pngData() -> Data? {
        guard let cgImage = self.cgImage else {
            return nil
        }

        let bitmapRepresentation = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRepresentation.representation(using: .png, properties: [:])
    }

    public var cgImage: CGImage? {
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

}

#endif

extension Image {

    static func clockMedium() -> Image {
        return Image(named: "ClockMedium")!
    }

    static func clockMediumC() -> Image {
        return Image(named: "ClockMediumC")!
    }

    static func dataIcon() -> Image {
        return Image(named: "DataIcon")!
    }

    static func dataIconC() -> Image {
        return Image(named: "DataIconC")!
    }

    static func epocLogo() -> Image {
        return Image(named: "EpocLogo")!
    }

    static func epocLogoC() -> Image {
        return Image(named: "EpocLogoC")!
    }

    static func folderIcon() -> Image {
        return Image(named: "FolderIcon")!
    }

    static func folderIconC() -> Image {
        return Image(named: "FolderIconC")!
    }

    static func installerIcon() -> Image {
        return Image(named: "InstallerIcon")!
    }

    static func installerIconC() -> Image {
        return Image(named: "InstallerIconC")!
    }

    static func oplIcon() -> Image {
        return Image(named: "OplIcon")!
    }

    static func oplIconC() -> Image {
        return Image(named: "OplIconC")!
    }

    static func opoIcon() -> Image {
        return Image(named: "OpoIcon")!
    }

    static func opoIconC() -> Image {
        return Image(named: "OpoIconC")!
    }

    static func paintIcon() -> Image {
        return Image(named: "PaintIcon")!
    }

    static func paintIconC() -> Image {
        return Image(named: "PaintIconC")!
    }

    static func recordIcon() -> Image {
        return Image(named: "RecordIcon")!
    }

    static func recordIconC() -> Image {
        return Image(named: "RecordIconC")!
    }

    static func textIcon() -> Image {
        return Image(named: "TextIcon")!
    }

    static func unknownAppIcon() -> Image {
        return Image(named: "UnknownAppIcon")!
    }

    static func unknownAppIconC() -> Image {
        return Image(named: "UnknownAppIconC")!
    }

    static func unknownFileIcon() -> Image {
        return Image(named: "UnknownFileIcon")!
    }

    static func unknownFileIconC() -> Image {
        return Image(named: "UnknownFileIconC")!
    }

    static func ditherPattern() -> Image {
        return Image(named: "DitherPattern")!
    }

}
