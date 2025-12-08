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

struct SoftwareIndexProgramsView: View {

    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var libraryModel: SoftwareIndexLibraryModel

    var body: some View {
        VStack {
            if libraryModel.isLoading {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240))], spacing: 0) {
                        ForEach(libraryModel.filteredPrograms) { program in
                            NavigationLink {
                                SoftwareIndexProgramView(program: program)
                                    .environmentObject(libraryModel)
                            } label: {
                                SoftwareIndexProgramRowLabel(imageURL: program.iconURL, title: program.name)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.trailing)
                }
            }
        }
        .searchable(text: $libraryModel.searchFilter)
        .navigationTitle("Software Index")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    if #available(iOS 26, *) {
                        Image(systemName: "xmark")
                    } else {
                        Text("Cancel")
                    }
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .onAppear {
            libraryModel.start()
        }
        .environmentObject(libraryModel)
    }

}
