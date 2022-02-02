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

    private var settings: Settings
    private var taskManager: TaskManager
    private var detector: ProgramDetector
    private var items: [Directory.Item] = []
    private var settingsSink: AnyCancellable?
    private var firstRun = true

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

    init(settings: Settings, taskManager: TaskManager, detector: ProgramDetector) {
        self.settings = settings
        self.taskManager = taskManager
        self.detector = detector
        super.init(collectionViewLayout: IconCollectionViewLayout())
        view.backgroundColor = .systemBackground
        collectionView.preservesSuperviewLayoutMargins = true
        collectionView.insetsLayoutMarginsFromSafeArea = true
        collectionView.backgroundView = wallpaperView
        collectionView.dataSource = dataSource
        title = "All Programs"
        navigationItem.searchController = searchController
        navigationItem.largeTitleDisplayMode = .never
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settingsSink = settings.objectWillChange.sink { [weak self] _ in
            guard let self = self else {
                return
            }
            self.wallpaperPixelView.image = self.settings.theme.wallpaper
            self.wallpaperPixelView.isHidden = !self.settings.showWallpaper
        }
        taskManager.addObserver(self)
        detector.delegate = self
        self.wallpaperPixelView.image = self.settings.theme.wallpaper
        wallpaperPixelView.isHidden = !settings.showWallpaper
        navigationController?.setToolbarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        update(animated: firstRun ? false : animated)
        firstRun = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        settingsSink?.cancel()
        settingsSink = nil
        detector.delegate = nil
        taskManager.removeObserver(self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    func actions(for url: URL) -> [UIMenuElement] {
        var actions: [UIMenuElement] = []

        let runAction = UIAction(title: "Run", image: UIImage(systemName: "play")) { action in
            let program = self.taskManager.program(for: url)
            let viewController = ProgramViewController(settings: self.settings,
                                                       taskManager: self.taskManager,
                                                       program: program)
            self.navigationController?.pushViewController(viewController, animated: true)
        }
        actions.append(runAction)
        return actions
    }

    func update(animated: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        items = detector.items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        var snapshot = Snapshot()
        snapshot.appendSections([.none])
        let filter = searchController.searchBar.text ?? ""
        let items = items.filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) }
            .map { item -> Item in
                var isRunning = false
                if let programUrl = item.programUrl, taskManager.isRunning(programUrl) {
                    isRunning = true
                }
                return Item(directoryItem: item, icon: item.icon, isRunning: isRunning)
            }
        snapshot.appendItems(items, toSection: Section.none)
        dataSource.apply(snapshot, animatingDifferences: animated)
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
        case .unknown, .applicationInformation, .sound, .help, .directory, .installer, .image, .text:
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
        return UIContextMenuConfiguration(identifier: indexPath.item as NSNumber,
                                          previewProvider: nil) { suggestedActions in
            switch item.type {
            case .object, .application, .system:
                var actions = self.actions(for: item.programUrl!)
                if let programUrl = item.programUrl {
                    actions += item.configurationActions(errorHandler: { error in
                        self.present(error: error)
                    })
                    actions += self.taskManager.actions(for: programUrl)
                }
                return UIMenu(children: actions)
            case .directory, .installer, .unknown, .applicationInformation, .image, .sound, .help, .text:
                return nil
            }
        }
    }

}

extension AllProgramsViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        update(animated: true)
    }

}

extension AllProgramsViewController: TaskManagerObserver {

    func taskManagerDidUpdate(_ taskManager: TaskManager) {
        update(animated: true)
    }

}

extension AllProgramsViewController: ProgramDetectorDelegate {

    func programDetectorDidUpdateItems(_ programDetector: ProgramDetector) {
        update(animated: true)
    }

    func programDetector(_ programDetector: ProgramDetector, didFailWithError error: Error) {
        present(error: error)
    }

}
