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

struct ProgramsView: View {

    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var libraryModel: LibraryModel

    var body: some View {
        List {
            ForEach(libraryModel.filteredPrograms) { program in
                NavigationLink {
                    ProgramView(program: program)
                        .environmentObject(libraryModel)
                } label: {
                    Label {
                        Text(program.name)
                    } icon: {
                        if let iconURL = program.iconURL {
                            AsyncImage(url: iconURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Image(systemName: "app.dashed")
                                    .foregroundColor(.secondary)
                            }

                        } else {
                            Image(systemName: "app.dashed")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .searchable(text: $libraryModel.filter)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {

            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("Psion Software Index")
                        .font(.headline)
                    Text("\(libraryModel.filteredPrograms.count) Programs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ToolbarItem(placement: .destructiveAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            libraryModel.start()
        }
        .environmentObject(libraryModel)
    }

}
