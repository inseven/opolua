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

import SwiftUI

class LibraryModelBlockDelegate: LibraryModelDelegate {

    let complete: (SoftwareIndexView.Item?) -> Void

    init(complete: @escaping (SoftwareIndexView.Item?) -> Void) {
        self.complete = complete
    }

    func libraryModelDidCancel(libraryModel: LibraryModel) {
        self.complete(nil)
    }

    func libraryModel(libraryModel: LibraryModel, didSelectItem item: SoftwareIndexView.Item) {
        self.complete(item)
    }

}

// TODO: Rename?
public struct SoftwareIndexView: View {

    public struct Item {

        public let sourceURL: URL
        public let url: URL

    }

    @StateObject var model: LibraryModel

    let delegate: LibraryModelBlockDelegate?

    init(model: LibraryModel) {
        _model = StateObject(wrappedValue: model)
        delegate = nil
    }

    public init(filter: @escaping (Release) -> Bool = { _ in true },
                completion: @escaping (SoftwareIndexView.Item?) -> Void) {
        let delegate = LibraryModelBlockDelegate(complete: completion)
        let libraryModel = LibraryModel(filter: filter)
        libraryModel.delegate = delegate
        _model = StateObject(wrappedValue: libraryModel)
        self.delegate = delegate
    }

    public var body: some View {
#if os(macOS)
        NavigationStack {
            ProgramsView()
                .environmentObject(model)
        }
        .frame(width: 600, height: 400)
#else
        NavigationView {
            ProgramsView()
                .environmentObject(model)
        }
        .navigationViewStyle(.stack)
#endif
    }

}
