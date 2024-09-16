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

extension URL {

    static let softwareIndexAPIV1 = URL(string: "https://software.psion.info/api/v1")!

}

protocol LibraryModelDelegate: AnyObject {

    func libraryModelDidCancel(libraryModel: LibraryModel)
    func libraryModel(libraryModel: LibraryModel, didSelectURL url: URL)

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
        let icon: Image?
        let reference: [ReferenceItem]

        var iconURL: URL? {
            guard let icon else {
                return nil
            }
            return URL.softwareIndexAPIV1.appendingPathComponent(icon.path)
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

    struct Image: Codable {

        let width: Int
        let height: Int
        let path: String

    }

    struct Program: Codable, Identifiable {

        var id: String {
            return uid
        }

        let uid: String  // TODO: Rename to 'identifier'
        let name: String
        let icon: Image?
        let versions: [Version]
        let tags: [String]
        var screenshots: [String]?

        var iconURL: URL? {
            guard let icon else {
                return nil
            }
            return URL.softwareIndexAPIV1.appendingPathComponent(icon.path)
        }

    }

    @Published @MainActor var programs: [Program] = []
    @Published @MainActor var filter: String = ""
    @Published @MainActor var filteredPrograms: [Program] = []

    private var cancellables: Set<AnyCancellable> = []

    weak var delegate: LibraryModelDelegate?

    init() {
    }

    @MainActor func start() {
        $programs
            .combineLatest($filter)
            .map { programs, filter in
               return programs.filter { filter.isEmpty || $0.name.localizedStandardContains(filter) }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.filteredPrograms, on: self)
            .store(in: &cancellables)
        Task {
            await self.fetch()
        }
    }

    @MainActor func stop() {
        cancellables.removeAll()
    }

    private func fetch() async {
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
                               tags: program.tags,
                               screenshots: program.screenshots)
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
            print("No download URL!")
            return
        }
        let (url, _) = try await URLSession.shared.download(from: downloadURL)
        DispatchQueue.main.async {
            self.delegate?.libraryModel(libraryModel: self, didSelectURL: url)
        }
    }

}
