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

class DirectoryViewController : UICollectionViewController {

    private enum Section {
        case none
    }

    private struct Item: Hashable {
        var directoryItem: Directory.Item
        var icon: Icon
        var isRunning: Bool
        var theme: Settings.Theme
    }

    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    private typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    private typealias Cell = IconCollectionViewCell

    private var settings: Settings
    private var taskManager: TaskManager
    var directory: Directory
    private var installer: Installer?
    private var applicationActiveObserver: Any?
    private var settingsSink: AnyCancellable?

    override var canBecomeFirstResponder: Bool {
        return true
    }

    private lazy var wallpaperPixelView: PixelView = {
        let image = settings.theme.wallpaper
        let pixelView = PixelView(image: image)
        pixelView.translatesAutoresizingMaskIntoConstraints = false
        pixelView.backgroundColor = .clear
        return pixelView
    }()

    private lazy var wallpaperView: UIView = {
        let view = UIView(frame: .zero)
        view.addSubview(wallpaperPixelView)
        NSLayoutConstraint.activate([
            wallpaperPixelView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            wallpaperPixelView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view
    }()

    private lazy var dataSource: DataSource = {
        let cellRegistration = UICollectionView.CellRegistration<Cell, Item> { [weak self] cell, _, item in
            guard let self = self else {
                return
            }
            cell.textLabel.text = item.directoryItem.name
            cell.detailTextLabel.text = item.isRunning ? "Running" : nil
            cell.imageView.image = item.icon.image(for: item.theme).scale(self.view.window?.screen.nativeScale ?? 1.0)
        }
        let dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        return dataSource
    }()

    private lazy var searchController: UISearchController = {
        let searchController = UISearchController()
        searchController.searchResultsUpdater = self
        return searchController
    }()

    init(settings: Settings, taskManager: TaskManager, directory: Directory) {
        self.settings = settings
        self.taskManager = taskManager
        self.directory = directory
        super.init(collectionViewLayout: IconCollectionViewLayout())
        self.directory.delegate = self
        view.backgroundColor = .systemBackground
        collectionView.preservesSuperviewLayoutMargins = true
        collectionView.insetsLayoutMarginsFromSafeArea = true
        collectionView.backgroundView = wallpaperView
        collectionView.dataSource = dataSource
        title = directory.localizedName
        navigationItem.searchController = searchController
        navigationItem.largeTitleDisplayMode = .never
        update(animated: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let notificationCenter = NotificationCenter.default
        // TODO: Push this into the directory observer.
        applicationActiveObserver = notificationCenter.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                                   object: nil,
                                                                   queue: nil) { [weak self] notification in
            guard let self = self else {
                return
            }
            self.directory.refresh()
        }
        directory.start()
        settingsSink = settings.objectWillChange.sink { [weak self] _ in
            guard let self = self else {
                return
            }
            self.wallpaperPixelView.image = self.settings.theme.wallpaper
            self.wallpaperPixelView.isHidden = !self.settings.showWallpaper
            self.update(animated: true)
        }
        taskManager.addObserver(self)
        self.wallpaperPixelView.image = self.settings.theme.wallpaper
        wallpaperPixelView.isHidden = !settings.showWallpaper
        navigationController?.setToolbarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        update(animated: animated)
        becomeFirstResponder()
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

    func delete(item: Directory.Item) {
        let alertController = UIAlertController(title: "Delete '\(item.name)'?", message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive) { action in
            do {
                try FileManager.default.removeItem(at: item.url)
            } catch {
                self.present(error: error)
            }
        })
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alertController, animated: true)
    }

    func pushDirectoryViewController(for url: URL) {
        let directory = Directory(url: url)
        let viewController = DirectoryViewController(settings: settings,
                                                     taskManager: taskManager,
                                                     directory: directory)
        navigationController?.pushViewController(viewController, animated: true)
    }

    func primaryActions(for item: Directory.Item) -> [UIMenuElement] {
        var actions: [UIMenuElement] = []

        if let url = item.programUrl {

            let runAction = UIAction(title: "Run", image: UIImage(systemName: "play")) { action in
                let program = self.taskManager.program(for: url)
                let viewController = ProgramViewController(settings: self.settings,
                                                           taskManager: self.taskManager,
                                                           program: program)
                self.navigationController?.pushViewController(viewController, animated: true)
            }
            actions.append(runAction)

            if case Directory.Item.ItemType.system = item.type {
                let contentsAction = UIAction(title: "Show Contents", image: UIImage(systemName: "folder")) { action in
                    self.pushDirectoryViewController(for: item.url)
                }
                actions.append(contentsAction)
            }

        } else {

            switch item.type {
            case .object, .application, .system:
                break
            case .directory:
                break
            case .installer:
                actions.append(UIAction(title: "Install", image: UIImage(systemName: "square.and.arrow.down")) { action in
                    AppDelegate.shared.install(url: item.url, preferredDestinationUrl: self.directory.url)
                })
            case .image:
                actions.append(UIAction(title: "View", image: UIImage(systemName: "eye")) { action in
                    let viewController = ImageViewController(url: item.url)
                    self.navigationController?.pushViewController(viewController, animated: true)
                })
            case .text:
                actions.append(UIAction(title: "View", image: UIImage(systemName: "eye")) { action in
                    let sourceViewController = SourceViewController(url: item.url)
                    self.navigationController?.pushViewController(sourceViewController, animated: true)
                })
            case .opl:
                break // TODO
            case .unknown, .applicationInformation, .sound, .help:
                break
            }

        }
        return actions
    }

    func fileActions(for item: Directory.Item) -> [UIMenuElement] {
        guard item.isWriteable else {
            return []
        }
        let deleteAction = UIAction(title: "Delete",
                                    image: UIImage(systemName: "trash"),
                                    attributes: .destructive) { action in
            self.delete(item: item)
        }
        return [UIMenu(options: [.displayInline], children: [deleteAction])]
    }

    private func update(animated: Bool) {
        var snapshot = Snapshot()
        snapshot.appendSections([.none])
        let items = directory.items(filter: searchController.searchBar.text)
            .map { item -> Item in
                var isRunning = false
                if let programUrl = item.programUrl, taskManager.isRunning(programUrl) {
                    isRunning = true
                }
                return Item(directoryItem: item, icon: item.icon, isRunning: isRunning, theme: settings.theme)
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
        case .object, .application:
            let program = taskManager.program(for: item.programUrl!)
            let viewController = ProgramViewController(settings: settings, taskManager: taskManager, program: program)
            navigationController?.pushViewController(viewController, animated: true)
        case .system:
            let program = taskManager.program(for: item.programUrl!)
            let viewController = ProgramViewController(settings: settings, taskManager: taskManager, program: program)
            navigationController?.pushViewController(viewController, animated: true)
        case .directory:
            pushDirectoryViewController(for: item.url)
        case .installer:
            AppDelegate.shared.install(url: item.url, preferredDestinationUrl: directory.url)
        case .image:
            let viewController = ImageViewController(url: item.url)
            navigationController?.pushViewController(viewController, animated: true)
        case .text, .opl:
            let sourceViewController = SourceViewController(url: item.url)
            navigationController?.pushViewController(sourceViewController, animated: true)
        case .unknown, .applicationInformation, .sound, .help:
            let alert = UIAlertController(title: "Unsupported File",
                                          message: "Opening files of this type is currently unsupported.",
                                          preferredStyle: .alert)
            alert.addAction(.init(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
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
        var actions: [UIMenuElement] = []
        actions += self.primaryActions(for: item)
        actions += item.configurationActions(errorHandler: { error in
            self.present(error: error)
        })
        if let programUrl = item.programUrl {
            actions += self.taskManager.actions(for: programUrl)
        }
        actions += self.fileActions(for: item)
        guard actions.count > 0 else {
            return nil
        }
        return UIContextMenuConfiguration(identifier: indexPath.item as NSNumber,
                                          previewProvider: nil) { suggestedActions in
            return UIMenu(children: actions)
        }
    }

}

extension DirectoryViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        update(animated: true)
    }

}

extension DirectoryViewController: DirectoryDelegate {

    func directoryDidUpdate(_ directory: Directory) {
        dispatchPrecondition(condition: .onQueue(.main))
        update(animated: true)
    }

    func directory(_ directory: Directory, didFailWithError error: Error) {
        dispatchPrecondition(condition: .onQueue(.main))
        present(error: error)
    }
    
}

extension DirectoryViewController: TaskManagerObserver {

    func taskManagerDidUpdate(_ taskManager: TaskManager) {
        update(animated: true)
    }

}
