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

struct SoftwareIndexProgramView: View {

    @EnvironmentObject private var libraryModel: SoftwareIndexLibraryModel

    var program: SoftwareIndex.Program

    var body: some View {
        List {
            if !(program.screenshots ?? []).isEmpty {
                Section {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(program.screenshots ?? [], id: \.path) { screenshot in
                                AsyncImage(url: URL.softwareIndexAPIV1.appendingPathComponent(screenshot.path)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .cornerRadius(8)
                                        .transition(.opacity.animation(.easeInOut))
                                } placeholder: {
                                    Rectangle()
                                        .fill(.tertiary)
                                        .aspectRatio(CGFloat(screenshot.width) / CGFloat(screenshot.height),
                                                     contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .cornerRadius(8)
                                        .transition(.opacity.animation(.easeInOut))
                                }
                            }
                        }
                    }
                }
                if let description = program.description {
                    Text(description)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            ForEach(program.versions) { version in
                Section {
                    ForEach(version.variants) { variant in
                        ForEach(variant.items, id: \.uniqueId) { item in
                            HStack(alignment: .center) {
                                SoftwareIndexIconView(url: item.iconURL)
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                    Text(String(item.sha256.prefix(8)))
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
//                                        .monospaced()
                                }
                                Spacer()
                                Text(item.size.formatted(.byteCount(style: .file)))
                                    .foregroundStyle(.secondary)
                                if let task = libraryModel.downloads[item.downloadURL] {
                                    HStack {
                                        ProgressView(task.progress)
                                            .progressViewStyle(.circular)
//                                            .progressViewStyle(.unadornedCircular)  //??
                                            .controlSize(.small)
                                        Button("Cancel") {
                                            libraryModel.downloads[item.downloadURL]?.cancel()
                                        }
                                    }
                                } else {
                                    Button {
                                        libraryModel.download(item)
                                    } label: {
                                        Text("Install")
                                    }
                                    .buttonStyle(.bordered)
                                    .buttonBorderShape(.capsule)
                                }
                            }
                        }
                    }
                } header: {
                    Text(version.version)
                }
            }
        }
        .listStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(program.name)
    }

}
