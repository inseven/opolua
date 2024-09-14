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

protocol SoftwareIndexViewControllerDelegate: AnyObject {

    func softwareIndexViewCntrollerDidCancel(softwareIndexViewController: SoftwareIndexViewController)
    func softwareIndexViewCntroller(softwareIndexViewCntroller: SoftwareIndexViewController, didSelectURL url: URL)

}

class SoftwareIndexViewController: UIHostingController<Library> {

    weak var delegate: SoftwareIndexViewControllerDelegate?

    private var libraryModel = LibraryModel()

    @MainActor init() {
        super.init(rootView: Library(model: libraryModel))
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

protocol LibraryModelDelegate: AnyObject {

    func libraryModelDidCancel(libraryModel: LibraryModel)
    func libraryModel(libraryModel: LibraryModel, didSelectURL url: URL)

}

func downloadFile(from url: URL) async throws -> URL {
    let session = URLSession.shared

    // Download the file using async/await
    let (tempLocalUrl, response) = try await session.download(from: url)

    // Extract the filename from the response or use the URL's last path component
    let fileName = (response as? HTTPURLResponse)?.suggestedFilename ?? url.lastPathComponent

    // Create the destination URL in the temporary directory
    let tempDirectory = FileManager.default.temporaryDirectory
    let destinationURL = tempDirectory.appendingPathComponent(fileName)

    // Move the downloaded file to the destination
    try FileManager.default.moveItem(at: tempLocalUrl, to: destinationURL)

    return destinationURL
}

class LibraryModel: ObservableObject {

    enum Kind: String, Codable {
        case installer
        case standalone
    }

    struct ReferenceItem: Codable {

        let name: String
        let url: URL?

    }

    struct Release: Codable, Identifiable {

        var id: String {
            return uid + referenceString
        }

        let uid: String  // TODO: Rename to 'identifier'
        let kind: Kind
        let icon: String?
        let reference: [ReferenceItem]

        var iconURL: URL? {
            guard let icon else {
                return nil
            }
            return URL(string: "https://software.psion.info/api/v1/")!
                .appendingPathComponent(icon)
        }

        var referenceString: String {
            return reference
                .map { $0.name }
                .joined(separator: " - ")
        }

        var hasDownload: Bool {
            return reference.last?.url != nil
        }

        var filename: String {
            return reference.last!.name.lastPathComponent
        }

        var downloadURL: URL? {
            return reference.last?.url
        }

    }

    struct Collection: Codable, Identifiable {

        var id: String {
            return identifier
        }

        let identifier: String
        let items: [Release]

    }

    struct Version: Codable, Identifiable {

        var id: String {
            return version
        }

        let version: String  // TODO: Rename to 'identifier'
        let variants: [Collection]  // TODO: Is this actually a good name?

    }

    struct Program: Codable, Identifiable {

        var id: String {
            return uid
        }

        let uid: String  // TODO: Rename to 'identifier'
        let name: String
        let icon: String?
        let versions: [Version]
        let tags: [String]

        var iconURL: URL? {
            guard let icon else {
                return nil
            }
            return URL(string: "https://software.psion.info/api/v1/")!
                .appendingPathComponent(icon)
        }

    }

    @Published @MainActor var programs: [Program] = []

    @MainActor var filter: String = ""

    @MainActor var filteredPrograms: [Program] {
        return programs.filter { filter.isEmpty || $0.name.localizedStandardContains(filter) }
    }

    weak var delegate: LibraryModelDelegate?

    init() {
    }

    // TODO: Filter for only OPL.

    func fetch() async {
        let url = URL(string: "https://software.psion.info/api/v1/programs.json")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            // TODO: Check for success
            let decoder = JSONDecoder()
            let programs = try decoder.decode([Program].self, from: data).compactMap { program -> Program? in

                let versions: [Version] = program.versions.compactMap { version in

                    let variants: [Collection] = version.variants.compactMap { collection in

                        let items: [Release] = collection.items.compactMap { release in
                            guard release.kind == .installer && release.hasDownload else {
                                return nil
                            }
                            return Release(uid: release.uid,
                                           kind: release.kind,
                                           icon: release.icon,
                                           reference: release.reference)
                        }

                        guard let release = items.first else {
                            return nil
                        }

                        return Collection(identifier: collection.identifier, items: [release])

                    }

                    guard variants.count > 0 else {
                        return nil
                    }

                    return Version(version: version.version, variants: variants)

                }

                guard versions.count > 0 && program.tags.contains("opl") else {
                    return nil
                }

                return Program(uid: program.uid,
                               name: program.name,
                               icon: program.icon,
                               versions: versions,
                               tags: program.tags)
            }

            await MainActor.run {
                self.programs = programs
            }
        } catch {
            print("Failed to fetch data with error \(error).")
        }
    }

    func install(release: Release) async throws {
        guard let downloadURL = release.downloadURL else {
            // TODO: Handle this error.
            print("No download URL!")
            return
        }

//        let url = try await downloadFile(from: downloadURL)
        let (url, _) = try await URLSession.shared.download(from: downloadURL)

        DispatchQueue.main.async {
            self.delegate?.libraryModel(libraryModel: self, didSelectURL: url)
        }
    }

}

struct ReleaseView: View {

    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var libraryModel: LibraryModel

    var release: LibraryModel.Release

    var body: some View {
        VStack {
            Button("Install") {
                Task {
                    do {
                        try await libraryModel.install(release: release)
                    } catch {
                        print("Failed to install software with error")
                    }
                }
            }
        }
        .navigationTitle(release.filename)

    }

}

struct ProgramView: View {

    @EnvironmentObject private var libraryModel: LibraryModel

    var program: LibraryModel.Program

    var body: some View {
        List {
            ForEach(program.versions) { version in
                Section(version.id) {
                    ForEach(version.variants) { variant in
                        ForEach(variant.items) { item in
                            NavigationLink {
                                ReleaseView(release: item)
                                    .environmentObject(libraryModel)
                            } label: {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text(item.filename)
                                        Text(item.referenceString)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    if let iconURL = item.iconURL {
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
                }
            }
        }
        .navigationTitle(program.name)
        .navigationBarTitleDisplayMode(.inline)
    }

}

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
            Task {
                await libraryModel.fetch()
            }
        }
        .environmentObject(libraryModel)
    }

}

struct Library: View {

    @StateObject var model: LibraryModel

    init(model: LibraryModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        NavigationView {
            ProgramsView()
                .environmentObject(model)
        }
        .navigationViewStyle(.stack)
    }

}
