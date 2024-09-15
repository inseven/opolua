// Copyright (c) 2024 Jason Morley
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

import Combine
import SwiftUI

protocol SoftwareIndexViewControllerDelegate: AnyObject {

    func softwareIndexViewCntrollerDidCancel(softwareIndexViewController: SoftwareIndexViewController)
    func softwareIndexViewCntroller(softwareIndexViewCntroller: SoftwareIndexViewController, didSelectURL url: URL)

}

class SoftwareIndexViewController: UIHostingController<SoftwareIndexView> {

    weak var delegate: SoftwareIndexViewControllerDelegate?

    private var libraryModel = LibraryModel()

    @MainActor init() {
        super.init(rootView: SoftwareIndexView(model: libraryModel))
        libraryModel.delegate = self
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension SoftwareIndexViewController: LibraryModelDelegate {

    func libraryModelDidCancel(libraryModel: LibraryModel) {
        delegate?.softwareIndexViewCntrollerDidCancel(softwareIndexViewController: self)
    }

    func libraryModel(libraryModel: LibraryModel, didSelectURL url: URL) {
        delegate?.softwareIndexViewCntroller(softwareIndexViewCntroller: self, didSelectURL: url)
    }

}
