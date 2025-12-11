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

#if canImport(UIKit)

import UIKit
typealias CommonImage = UIImage
typealias CommonImageView = UIImageView

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

extension CommonImage {

    static func clockMedium() -> CommonImage {
        return CommonImage(named: "ClockMedium")!
    }

    static func clockMediumC() -> CommonImage {
        return CommonImage(named: "ClockMediumC")!
    }

    static func dataIcon() -> CommonImage {
        return CommonImage(named: "DataIcon")!
    }

    static func dataIconC() -> CommonImage {
        return CommonImage(named: "DataIconC")!
    }

    static func epocLogo() -> CommonImage {
        return CommonImage(named: "EpocLogo")!
    }

    static func epocLogoC() -> CommonImage {
        return CommonImage(named: "EpocLogoC")!
    }

    static func folderIcon() -> CommonImage {
        return CommonImage(named: "FolderIcon")!
    }

    static func folderIconC() -> CommonImage {
        return CommonImage(named: "FolderIconC")!
    }

    static func installerIcon() -> CommonImage {
        return CommonImage(named: "InstallerIcon")!
    }

    static func installerIconC() -> CommonImage {
        return CommonImage(named: "InstallerIconC")!
    }

    static func oplIcon() -> CommonImage {
        return CommonImage(named: "OplIcon")!
    }

    static func oplIconC() -> CommonImage {
        return CommonImage(named: "OplIconC")!
    }

    static func opoIcon() -> CommonImage {
        return CommonImage(named: "OpoIcon")!
    }

    static func opoIconC() -> CommonImage {
        return CommonImage(named: "OpoIconC")!
    }

    static func paintIcon() -> CommonImage {
        return CommonImage(named: "PaintIcon")!
    }

    static func paintIconC() -> CommonImage {
        return CommonImage(named: "PaintIconC")!
    }

    static func recordIcon() -> CommonImage {
        return CommonImage(named: "RecordIcon")!
    }

    static func recordIconC() -> CommonImage {
        return CommonImage(named: "RecordIconC")!
    }

    static func textIcon() -> CommonImage {
        return CommonImage(named: "TextIcon")!
    }

    static func unknownAppIcon() -> CommonImage {
        return CommonImage(named: "UnknownAppIcon")!
    }

    static func unknownAppIconC() -> CommonImage {
        return CommonImage(named: "UnknownAppIconC")!
    }

    static func unknownFileIcon() -> CommonImage {
        return CommonImage(named: "UnknownFileIcon")!
    }

    static func unknownFileIconC() -> CommonImage {
        return CommonImage(named: "UnknownFileIconC")!
    }

    static func ditherPattern() -> CommonImage {
        return CommonImage(named: "DitherPattern")!
    }

}
