// Copyright (c) 2021-2022 Jason Morley, Tom Sutcliffe
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
import Foundation
import UIKit

class AllProgramsViewController : UICollectionViewController {

    enum Section {
        case none
    }

    struct Item: Hashable {
        var directoryItem: Directory.Item
        var icon: Icon
        var isRunning: Bool
    }

    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias Cell = IconCollectionViewCell

    static var cell = "Cell"

    var settings: Settings
    var taskManager: TaskManager
    var detector: ProgramDetector
    var items: [Directory.Item] = []
    var applicationActiveObserver: Any?
    var settingsSink: AnyCancellable?

    static let defaultLocations = [
        Bundle.main.filesUrl,
        Bundle.main.examplesUrl,
        Bundle.main.scriptsUrl,
    ]

    lazy var wallpaperPixelView: PixelView = {
        let image = settings.theme.wallpaper
        let pixelView = PixelView(image: image)
        pixelView.translatesAutoresizingMaskIntoConstraints = false
        pixelView.backgroundColor = .clear
        return pixelView
    }()

    lazy var wallpaperView: UIView = {
        let view = UIView(frame: .zero)
        view.addSubview(wallpaperPixelView)
        NSLayoutConstraint.activate([
            wallpaperPixelView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            wallpaperPixelView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view
    }()

    lazy var dataSource: DataSource = {
        let cellRegistration = UICollectionView.CellRegistration<Cell, Item> { [weak self] cell, _, item in
            guard let self = self else {
                return
            }
            cell.textLabel.text = item.directoryItem.name
            cell.detailTextLabel.text = item.isRunning ? "Running" : nil
            cell.imageView.image = item.icon.image(for: self.settings.theme).scale(self.view.window?.screen.nativeScale ?? 1.0)
        }
        let dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        return dataSource
    }()

    lazy var searchController: UISearchController = {
        let searchController = UISearchController()
        searchController.searchResultsUpdater = self
        return searchController
    }()

    init(settings: Settings, taskManager: TaskManager) {
        self.settings = settings
        self.taskManager = taskManager
        self.detector = ProgramDetector(locations: Self.defaultLocations + settings.locations.map { $0.url })
        super.init(collectionViewLayout: IconCollectionViewLayout())
        view.backgroundColor = .systemBackground
        collectionView.preservesSuperviewLayoutMargins = true
        collectionView.insetsLayoutMarginsFromSafeArea = true
        collectionView.backgroundView = wallpaperView
        collectionView.dataSource = dataSource
        detector.delegate = self
        title = "All Programs"
        navigationItem.searchController = searchController
        navigationItem.largeTitleDisplayMode = .never
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let notificationCenter = NotificationCenter.default
        applicationActiveObserver = notificationCenter.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                                   object: nil,
                                                                   queue: nil) { [weak self] notification in
            guard let self = self else {
                return
            }
            self.reload()
        }
        settingsSink = settings.objectWillChange.sink { [weak self] _ in
            guard let self = self else {
                return
            }
            self.wallpaperPixelView.image = self.settings.theme.wallpaper
            self.wallpaperPixelView.isHidden = !self.settings.showWallpaper
        }
        taskManager.addObserver(self)
        self.wallpaperPixelView.image = self.settings.theme.wallpaper
        wallpaperPixelView.isHidden = !settings.showWallpaper
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        detector.update()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let observer = applicationActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        settingsSink?.cancel()
        settingsSink = nil
        taskManager.removeObserver(self)
    }

    func reload() {
        // TODO: Implement me.
    }

    func actions(for url: URL) -> [UIMenuElement] {
        var actions: [UIMenuElement] = []

        let runAction = UIAction(title: "Run") { action in
            let program = self.taskManager.program(for: url)
            let viewController = ProgramViewController(settings: self.settings,
                                                       taskManager: self.taskManager,
                                                       program: program)
            self.navigationController?.pushViewController(viewController, animated: true)
        }
        actions.append(runAction)

        let runAsActions = Device.allCases.map { device -> UIAction in
            var configuration = Configuration.load(for: url)
            return UIAction(title: device.name, state: configuration.device == device ? .on : .off) { action in
                configuration.device = device
                do {
                    try configuration.save(for: url)
                } catch {
                    self.present(error: error)
                }
            }
        }
        let runAsMenu = UIMenu(title: "Run As...", options: [.displayInline], children: runAsActions)
        actions.append(runAsMenu)

        return actions
    }

    func taskMenu(for url: URL) -> UIMenu? {
        guard taskManager.isRunning(url) else {
            return nil
        }
        let closeAction = UIAction(title: "Close Program", image: UIImage(systemName: "xmark")) { action in
            self.taskManager.quit(url)
        }
        return UIMenu(options: [.displayInline], children: [closeAction])
    }

    func snapshot(for items: [Directory.Item]) -> Snapshot {
        var snapshot = Snapshot()
        snapshot.appendSections([.none])
        let filter = searchController.searchBar.text ?? ""
        let items = items.filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) }
            .map { item -> Item in
                var isRunning = false
                if let programUrl = item.programUrl, taskManager.isRunning(programUrl) {
                    isRunning = true
                }
                return Item(directoryItem: item, icon: item.icon(), isRunning: isRunning)
            }
        snapshot.appendItems(items, toSection: Section.none)
        return snapshot
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath)?.directoryItem else {
            collectionView.deselectItem(at: indexPath, animated: true)
            return
        }
        switch item.type {
        case .object, .application, .system:
            let program = taskManager.program(for: item.programUrl!)
            let viewController = ProgramViewController(settings: settings, taskManager: taskManager, program: program)
            navigationController?.pushViewController(viewController, animated: true)
        case .unknown, .applicationInformation, .sound, .help, .directory, .installer, .image:
            break
        }
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let item = configuration.identifier as? NSNumber,
              let itemInt = item as? Int,
              let cell = collectionView.cellForItem(at: IndexPath(item: itemInt, section: 0)) as? Cell else {
                  return nil
              }
        return UITargetedPreview(view: cell.imageView)
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let item = configuration.identifier as? NSNumber,
              let itemInt = item as? Int,
              let cell = collectionView.cellForItem(at: IndexPath(item: itemInt, section: 0)) as? Cell else {
                  return nil
              }
        return UITargetedPreview(view: cell.imageView)
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 contextMenuConfigurationForItemAt indexPath: IndexPath,
                                 point: CGPoint) -> UIContextMenuConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath)?.directoryItem else {
            return nil
        }
        return UIContextMenuConfiguration(identifier: indexPath.item as NSNumber, previewProvider: nil) { suggestedActions in
            let deleteAction = UIAction(title: "Reveal in Library") { action in
                print("Reveal in library")
            }
            let fileMenu = UIMenu(options: [.displayInline], children: [deleteAction])
            switch item.type {
            case .object, .application, .system:
                var actions = self.actions(for: item.programUrl!)
                if let taskMenu = self.taskMenu(for: item.programUrl!) {
                    actions.append(taskMenu)
                }
                actions.append(fileMenu)
                return UIMenu(children: actions)
            case .directory, .installer, .unknown, .applicationInformation, .image, .sound, .help:
                return UIMenu(children: [fileMenu])
            }
        }
    }

}

extension AllProgramsViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        dataSource.apply(snapshot(for: items))
    }
    
}

extension AllProgramsViewController: TaskManagerObserver {

    func taskManagerDidUpdate(_ taskManager: TaskManager) {
        dataSource.apply(snapshot(for: items), animatingDifferences: true)
    }

}

extension AllProgramsViewController: ProgramDetectorDelegate {

    func programDetector(_ programDetector: ProgramDetector, didUpdateItems items: [Directory.Item]) {
        self.items = items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        dataSource.apply(snapshot(for: self.items))
    }

    func programDetector(_ programDetector: ProgramDetector, didFailWithError error: Error) {
        present(error: error)
    }


}