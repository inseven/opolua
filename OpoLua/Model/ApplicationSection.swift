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

import UIKit

enum ApplicationSection: Hashable {
    case runningPrograms
    case allPrograms
    case documents
    case local(URL)
    case external(URL)
}

extension ApplicationSection {

    var name: String {
        switch self {
        case .runningPrograms:
            return "Running Programs"
        case .allPrograms:
            return "All Programs"
        case .documents:
            return UIDevice.current.localizedDocumentsName
        case .local(let url):
            return url.localizedName
        case .external(let url):
            return url.localizedName
        }
    }

    var image: UIImage {
        switch self {
        case .runningPrograms:
            return UIImage(systemName: "play.square")!
        case .allPrograms:
            return UIImage(systemName: "square")!
        case .documents:
            switch UIDevice.current.userInterfaceIdiom {
            case .phone:
                return UIImage(systemName: "iphone")!
            case .pad:
                return UIImage(systemName: "ipad")!
            case .mac:
                return UIImage(systemName: "desktopcomputer")!
            default:
                return UIImage(systemName: "externaldrive")!
            }
        case .local(_):
            return UIImage(systemName: "folder")!
        case .external(_):
            return UIImage(systemName: "folder")!
        }
    }

    var isReadOnly: Bool {
        switch self {
        case .runningPrograms:
            return true
        case .allPrograms:
            return true
        case .documents:
            return true
        case .local(_):
            return true
        case .external(_):
            return false
        }
    }

}
