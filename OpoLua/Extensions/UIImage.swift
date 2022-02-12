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

extension UIImage {

    static func clockMedium() -> UIImage {
        return UIImage(named: "ClockMedium")!
    }

    static func clockMediumC() -> UIImage {
        return UIImage(named: "ClockMediumC")!
    }

    static func dataIcon() -> UIImage {
        return UIImage(named: "DataIcon")!
    }

    static func dataIconC() -> UIImage {
        return UIImage(named: "DataIconC")!
    }

    static func epocLogo() -> UIImage {
        return UIImage(named: "EpocLogo")!
    }

    static func epocLogoC() -> UIImage {
        return UIImage(named: "EpocLogoC")!
    }

    static func folderIcon() -> UIImage {
        return UIImage(named: "FolderIcon")!
    }

    static func folderIconC() -> UIImage {
        return UIImage(named: "FolderIconC")!
    }

    static func installerIcon() -> UIImage {
        return UIImage(named: "InstallerIcon")!
    }

    static func installerIconC() -> UIImage {
        return UIImage(named: "InstallerIconC")!
    }

    static func oplIcon() -> UIImage {
        return UIImage(named: "OplIcon")!
    }

    static func oplIconC() -> UIImage {
        return UIImage(named: "OplIconC")!
    }

    static func opoIcon() -> UIImage {
        return UIImage(named: "OpoIcon")!
    }

    static func opoIconC() -> UIImage {
        return UIImage(named: "OpoIconC")!
    }

    static func paintIcon() -> UIImage {
        return UIImage(named: "PaintIcon")!
    }

    static func paintIconC() -> UIImage {
        return UIImage(named: "PaintIconC")!
    }

    static func recordIcon() -> UIImage {
        return UIImage(named: "RecordIcon")!
    }

    static func recordIconC() -> UIImage {
        return UIImage(named: "RecordIconC")!
    }

    static func textIcon() -> UIImage {
        return UIImage(named: "TextIcon")!
    }

    static func unknownAppIcon() -> UIImage {
        return UIImage(named: "UnknownAppIcon")!
    }

    static func unknownAppIconC() -> UIImage {
        return UIImage(named: "UnknownAppIconC")!
    }

    static func unknownFileIcon() -> UIImage {
        return UIImage(named: "UnknownFileIcon")!
    }

    static func unknownFileIconC() -> UIImage {
        return UIImage(named: "UnknownFileIconC")!
    }

    static func emptyImage(with size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    func scale(_ scale: CGFloat) -> UIImage? {
        let size = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContext(size)
        defer {
            UIGraphicsEndImageContext()
        }
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        context.interpolationQuality = .none
        context.translateBy(x: 0, y: size.height);
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(self.cgImage!, in: CGRect(origin: .zero, size: size))
        guard let cgImage = context.makeImage() else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

}
