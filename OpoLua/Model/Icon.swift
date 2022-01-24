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
import SwiftUI

struct Icon: Hashable {

    static func == (lhs: Icon, rhs: Icon) -> Bool {
        return lhs.grayscaleImage == rhs.grayscaleImage && lhs.colorImage == rhs.colorImage
    }

    var grayscaleImage: UIImage
    var colorImage: UIImage

    init(grayscaleImage: UIImage, colorImage: UIImage) {
        self.grayscaleImage = grayscaleImage
        self.colorImage = colorImage
    }

}

extension Icon {

    func image(for theme: Settings.Theme) -> UIImage {
        switch theme {
        case .series5:
            return grayscaleImage
        case .series7:
            return colorImage
        }
    }

}

extension Icon {

    static var data = Icon(grayscaleImage: .dataIcon, colorImage: .dataIconC)
    static var folder = Icon(grayscaleImage: .folderIcon, colorImage: .folderIconC)
    static var image = Icon(grayscaleImage: .paintIcon, colorImage: .paintIconC)
    static var installer = Icon(grayscaleImage: .installerIcon, colorImage: .installerIconC)
    static var opo = Icon(grayscaleImage: .opoIcon, colorImage: .opoIconC)
    static var sound = Icon(grayscaleImage: .recordIcon, colorImage: .recordIconC)
    static var unknownApplication = Icon(grayscaleImage: .unknownAppIcon, colorImage: .unknownAppIcon)
    static var unknownFile = Icon(grayscaleImage: .unknownAppIcon, colorImage: .unknownFileIconC)

}

extension OpoInterpreter.AppInfo {

    func icon() -> Icon? {
        guard let appIcon = appIcon else {
            return nil
        }
        // TODO: Use grayscale images
        return Icon(grayscaleImage: appIcon, colorImage: appIcon)
    }

}
