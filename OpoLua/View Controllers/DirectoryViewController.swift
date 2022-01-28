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
    private var directory: Directory
    private var installer: Installer?
    private var applicationActiveObserver: Any?
    private var settingsSink: AnyCancellable?

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

    private lazy var menuBarButtonItem: UIBarButtonItem = {
        let newFolderAction = UIAction(title: "New Folder",
                                       image: UIImage(systemName: "folder.badge.plus")) { [weak self] action in
            guard let self = self else {
                return
            }
            self.createDirectory()
        }
        let menu = UIMenu(title: "", image: nil, identifier: nil, options: [], children: [newFolderAction])
        let menuBarButtonItem = UIBarButtonItem(title: nil,
                                                image: UIImage(systemName: "ellipsis.circle"),
                                                primaryAction: nil,
                                                menu: menu)
        return menuBarButtonItem
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
        title = directory.name
        navigationItem.searchController = searchController
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = menuBarButtonItem
        update(animated: false)
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

    func createDirectory() {
        let alertController = UIAlertController(title: "New Folder", message: nil, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "Name"
        }
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [unowned self, alertController] _ in
            do {
                try self.directory.createDirectory(name: alertController.textFields![0].text!)
            } catch {
                self.present(error: error)
            }
        })
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alertController, animated: true)
    }

    func delete(item: Directory.Item) {
        let alertController = UIAlertController(title: "Delete '\(item.name)'?", message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive) { action in
            do {
                try self.directory.delete(item)
            } catch {
                self.present(error: error)
            }
        })
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alertController, animated: true)
    }

    func reload() {
        do {
            try directory.refresh()
        } catch {
            present(error: error)
        }
    }

    func pushDirectoryViewController(for url: URL) {
        do {
            let directory = try Directory(url: url)
            let viewController = DirectoryViewController(settings: settings,
                                                         taskManager: taskManager,
                                                         directory: directory)
            navigationController?.pushViewController(viewController, animated: true)
        } catch {
            present(error: error)
        }
    }

    func programActions(for item: Directory.Item) -> [UIMenuElement] {
        guard let url = item.programUrl else {
            return []
        }
        var actions: [UIMenuElement] = []
        let runAction = UIAction(title: "Run") { action in
            let program = self.taskManager.program(for: url)
            let viewController = ProgramViewController(settings: self.settings,
                                                       taskManager: self.taskManager,
                                                       program: program)
            self.navigationController?.pushViewController(viewController, animated: true)
        }
        actions.append(runAction)

        if case Directory.Item.ItemType.system = item.type {
            let contentsAction = UIAction(title: "Show Package Contents") { action in
                self.pushDirectoryViewController(for: item.url)
            }
            actions.append(contentsAction)
        }

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

    func taskActions(for item: Directory.Item) -> [UIMenuElement] {
        guard let url = item.programUrl, taskManager.isRunning(url) else {
            return []
        }
        let closeAction = UIAction(title: "Close Program", image: UIImage(systemName: "xmark")) { action in
            self.taskManager.quit(url)
        }
        return [UIMenu(options: [.displayInline], children: [closeAction])]
    }

    func fileActions(for item: Directory.Item) -> [UIMenuElement] {
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
                return Item(directoryItem: item, icon: item.icon(), isRunning: isRunning, theme: settings.theme)
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
            let installerViewController = InstallerViewController(url: item.url, destinationUrl: directory.url)
            installerViewController.installerDelegate = self
            present(installerViewController, animated: true)
        case .image:
            let viewController = ImageViewController(url: item.url)
            navigationController?.pushViewController(viewController, animated: true)
        case .unknown, .applicationInformation, .sound, .help:
            let alert = UIAlertController(title: "Unsupported File", message: "Opening files of this type is currently unsupported.", preferredStyle: .alert)
            alert.addAction(.init(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
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
            var actions: [UIMenuElement] = []
            actions += self.programActions(for: item)
            actions += self.taskActions(for: item)
            actions += self.fileActions(for: item)
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

    func directoryDidChange(_ directory: Directory) {
        update(animated: true)
    }
}

extension DirectoryViewController: InstallerViewControllerDelegate {

    func installerViewControllerDidFinish(_ installerViewController: InstallerViewController) {
        dispatchPrecondition(condition: .onQueue(.main))
        installerViewController.dismiss(animated: true)
        reload()
    }

}

extension DirectoryViewController: TaskManagerObserver {

    func taskManagerDidUpdate(_ taskManager: TaskManager) {
        update(animated: true)
    }

}
