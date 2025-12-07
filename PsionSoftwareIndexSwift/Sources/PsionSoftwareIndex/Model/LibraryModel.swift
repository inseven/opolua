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

import Combine
import SwiftUI

/// Callbacks always occur on `MainActor`.
protocol LibraryModelDelegate: AnyObject {

    @MainActor func libraryModelDidCancel(libraryModel: LibraryModel)
    @MainActor func libraryModel(libraryModel: LibraryModel, didSelectItem item: SoftwareIndexView.Item)

}

@MainActor class LibraryModel: ObservableObject {

    @Published var programs: [Program] = []
    @Published var searchFilter: String = ""
    @Published var filteredPrograms: [Program] = []

    weak var delegate: LibraryModelDelegate?

    private var cancellables: Set<AnyCancellable> = []

    private let filter: (Release) -> Bool

    init(filter: @escaping (Release) -> Bool) {
        self.filter = filter
    }

    @MainActor func start() {
        $programs
            .combineLatest($searchFilter)
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

    @MainActor private func fetch() async {
        let url = URL.softwareIndexAPIV1.appendingPathComponent("programs")
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            // TODO: Check for success
            let decoder = JSONDecoder()
            let programs = try decoder.decode([Program].self, from: data).compactMap { program -> Program? in

                let versions: [Version] = program.versions.compactMap { version in

                    let variants: [Collection] = version.variants.compactMap { collection in

                        let items: [Release] = collection.items.compactMap { release -> Release? in
                            guard filter(release) else {
                                return nil
                            }
                            return Release(uid: release.uid,
                                           kind: release.kind,
                                           name: release.name,
                                           icon: release.icon,
                                           reference: release.reference,
                                           tags: release.tags)
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

                guard versions.count > 0 else {
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
        let item = SoftwareIndexView.Item(sourceURL: downloadURL, url: url)
        await MainActor.run {
            self.delegate?.libraryModel(libraryModel: self, didSelectItem: item)
        }
    }

}
