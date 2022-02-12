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
        if lhs.grayscaleImagePngData != rhs.grayscaleImagePngData {
            return false
        }
        if lhs.colorImagePngData != rhs.colorImagePngData {
            return false
        }
        return true
    }

    var grayscaleImage: UIImage
    var colorImage: UIImage
    private var grayscaleImagePngData: Data
    private var colorImagePngData: Data

    init(grayscaleImage: UIImage, colorImage: UIImage) {
        self.grayscaleImage = grayscaleImage
        self.colorImage = colorImage
        self.grayscaleImagePngData = grayscaleImage.pngData()!
        self.colorImagePngData = colorImage.pngData()!
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(grayscaleImagePngData)
        hasher.combine(colorImagePngData)
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

    static func data() -> Icon {
        return Icon(grayscaleImage: .dataIcon(), colorImage: .dataIconC())
    }

    static func folder() -> Icon {
        return Icon(grayscaleImage: .folderIcon(), colorImage: .folderIconC())
    }

    static func image() -> Icon {
        return Icon(grayscaleImage: .paintIcon(), colorImage: .paintIconC())
    }

    static func installer() -> Icon {
        return Icon(grayscaleImage: .installerIcon(), colorImage: .installerIconC())
    }

    static func opl() -> Icon {
        return Icon(grayscaleImage: .oplIcon(), colorImage: .oplIconC())
    }

    static func opo() -> Icon {
        return Icon(grayscaleImage: .opoIcon(), colorImage: .opoIconC())
    }
    
    static func sound() -> Icon {
        return Icon(grayscaleImage: .recordIcon(), colorImage: .recordIconC())
    }

    static func text() -> Icon {
        return Icon(grayscaleImage: .textIcon(), colorImage: .textIcon())
    }

    static func unknownApplication() -> Icon {
        return Icon(grayscaleImage: .unknownAppIcon(), colorImage: .unknownAppIconC())
    }

    static func unknownFile() -> Icon {
        return Icon(grayscaleImage: .unknownAppIcon(), colorImage: .unknownFileIconC())
    }

}
