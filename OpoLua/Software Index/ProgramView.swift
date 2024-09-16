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

import SwiftUI

struct ProgramView: View {

    @EnvironmentObject private var libraryModel: LibraryModel

    var program: LibraryModel.Program

    var body: some View {
        List {
            if !(program.screenshots ?? []).isEmpty {
                Section {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(program.screenshots ?? [], id: \.self) { screenshot in
                                AsyncImage(url: URL.softwareIndexAPIV1.appendingPathComponent(screenshot))
                            }
                        }
                    }
                }
            }
            ForEach(program.versions) { version in
                Section(version.id) {
                    ForEach(version.variants) { variant in
                        ForEach(variant.items) { item in
                            NavigationLink {
                                ReleaseView(release: item)
                                    .environmentObject(libraryModel)
                            } label: {
                                HStack(alignment: .center) {
                                    if let iconURL = item.iconURL {
                                        AsyncImage(url: iconURL) { image in
                                            image
                                        } placeholder: {
                                            Image(.unknownAppIconC)
                                        }
                                    } else {
                                        Image(.unknownAppIconC)
                                    }
                                    VStack(alignment: .leading) {
                                        Text(item.filename)
                                        Text(item.referenceString)
                                            .font(.footnote)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(program.name)
        .navigationBarTitleDisplayMode(.inline)
    }

}
