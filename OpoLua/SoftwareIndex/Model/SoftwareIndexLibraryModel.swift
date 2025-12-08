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
protocol SoftwareIndexLibraryModelDelegate: AnyObject {

    @MainActor
    func libraryModelDidCancel(libraryModel: SoftwareIndexLibraryModel)

    @MainActor
    func libraryModel(libraryModel: SoftwareIndexLibraryModel, didSelectItem item: SoftwareIndexView.Item)

}

@MainActor class SoftwareIndexLibraryModel: ObservableObject {

    @Published var isLoading: Bool = true
    @Published var programs: [SoftwareIndex.Program] = []
    @Published var searchFilter: String = ""
    @Published var filteredPrograms: [SoftwareIndex.Program] = []
    @Published var error: Error? = nil

    weak var delegate: SoftwareIndexLibraryModelDelegate?

    private var cancellables: Set<AnyCancellable> = []

    @Published var downloads: [URL: URLSessionDownloadTask] = [:]

    private let filter: (SoftwareIndex.Release) -> Bool

    init(filter: @escaping (SoftwareIndex.Release) -> Bool) {
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
        isLoading = true
        let url = URL.softwareIndexAPIV1.appendingPathComponent("programs")
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()

            // Filter the list to include only SIS files.
            let programs = try decoder.decode([SoftwareIndex.Program].self, from: data).compactMap { program -> SoftwareIndex.Program? in
                let versions: [SoftwareIndex.Version] = program.versions.compactMap { version in
                    let variants: [SoftwareIndex.Collection] = version.variants.compactMap { collection in
                        let items: [SoftwareIndex.Release] = collection.items.compactMap { release -> SoftwareIndex.Release? in
                            guard filter(release) else {
                                return nil
                            }
                            return release
                        }
                        guard let release = items.first else {
                            return nil
                        }
                        return SoftwareIndex.Collection(identifier: collection.identifier, items: [release])
                    }
                    guard variants.count > 0 else {
                        return nil
                    }
                    return SoftwareIndex.Version(version: version.version, variants: variants)
                }
                guard versions.count > 0 else {
                    return nil
                }
                return SoftwareIndex.Program(id: program.id,
                                             name: program.name,
                                             icon: program.icon,
                                             versions: versions,
                                             subtitle: program.subtitle,
                                             description: program.description,
                                             tags: program.tags,
                                             screenshots: program.screenshots)
            }.sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

            await MainActor.run {
                self.isLoading = false
                self.programs = programs
            }
        } catch {
            self.isLoading = false
            print("Failed to fetch data with error \(error).")
        }
    }

    func download(_ release: SoftwareIndex.Release) {
        dispatchPrecondition(condition: .onQueue(.main))

        // Ensure there are no active downloads for that URL.
        guard downloads[release.downloadURL] == nil else {
            return
        }

        let downloadURL = release.downloadURL

        // Create the download task.
        let downloadTask = URLSession.shared.downloadTask(with: downloadURL) { [weak self] url, response, error in
            dispatchPrecondition(condition: .notOnQueue(.main))
            guard let self else {
                return
            }
            do {
                // First, cean up the download task and observation.
                _ = DispatchQueue.main.sync {
                    self.downloads.removeValue(forKey: downloadURL)
                }

                // Check for errors.
                guard let url else {
                    throw error ?? OpoLuaError.unknownDownloadFailure
                }

                // Create a temporary directory and move the downloaded contents to ensure it has the correct filename.
                let fileManager = FileManager.default
                let temporaryDirectory = fileManager.temporaryDirectory.appendingPathComponent((UUID().uuidString))
                try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
                let itemURL = temporaryDirectory.appendingPathComponent(release.filename)
                try fileManager.moveItem(at: url, to: itemURL)

                // Call our delegate.
                let item = SoftwareIndexView.Item(sourceURL: downloadURL, url: itemURL)
                DispatchQueue.main.async {
                    self.delegate?.libraryModel(libraryModel: self, didSelectItem: item)
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                }
            }
        }

        // Cache the download task.
        self.downloads[downloadURL] = downloadTask

        // Start the download.
        downloadTask.resume()
    }

}
