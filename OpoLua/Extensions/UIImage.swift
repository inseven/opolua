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

    static var clockMedium: UIImage = {
        return UIImage(named: "ClockMedium")!
    }()

    static var clockMediumC: UIImage = {
        return UIImage(named: "ClockMediumC")!
    }()

    static var dataIcon: UIImage = {
        return UIImage(named: "DataIcon")!
    }()

    static var dataIconC: UIImage = {
        return UIImage(named: "DataIconC")!
    }()

    static var epocLogo: UIImage = {
        return UIImage(named: "EpocLogo")!
    }()

    static var epocLogoC: UIImage = {
        return UIImage(named: "EpocLogoC")!
    }()

    static var folderIcon: UIImage = {
        return UIImage(named: "FolderIcon")!
    }()

    static var folderIconC: UIImage = {
        return UIImage(named: "FolderIconC")!
    }()

    static var installerIcon: UIImage = {
        return UIImage(named: "InstallerIcon")!
    }()

    static var installerIconC: UIImage = {
        return UIImage(named: "InstallerIconC")!
    }()

    static var oplIcon: UIImage = {
        return UIImage(named: "OplIcon")!
    }()

    static var oplIconC: UIImage = {
        return UIImage(named: "OplIconC")!
    }()

    static var opoIcon: UIImage = {
        return UIImage(named: "OpoIcon")!
    }()

    static var opoIconC: UIImage = {
        return UIImage(named: "OpoIconC")!
    }()

    static var paintIcon: UIImage = {
        return UIImage(named: "PaintIcon")!
    }()

    static var paintIconC: UIImage = {
        return UIImage(named: "PaintIconC")!
    }()

    static var recordIcon: UIImage = {
        return UIImage(named: "RecordIcon")!
    }()

    static var recordIconC: UIImage = {
        return UIImage(named: "RecordIconC")!
    }()

    static var textIcon: UIImage = {
        return UIImage(named: "TextIcon")!
    }()

    static var unknownAppIcon: UIImage = {
        return UIImage(named: "UnknownAppIcon")!
    }()

    static var unknownFileIcon: UIImage = {
        return UIImage(named: "UnknownFileIcon")!
    }()

    static var unknownFileIconC: UIImage = {
        return UIImage(named: "UnknownFileIconC")!
    }()

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
