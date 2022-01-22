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

class DirectoryViewController : UIViewController {

    enum Section {
        case none
    }

    struct Item: Hashable {
        var directoryItem: Directory.Item
        var isRunning: Bool
    }

    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>

    class Cell: UICollectionViewCell {

        lazy var imageView: UIImageView = {
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.backgroundColor = .clear
            return imageView
        }()

        lazy var textLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.preferredFont(forTextStyle: .body)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 1
            label.textAlignment = .center
            label.lineBreakMode = .byTruncatingTail
            return label
        }()

        lazy var detailTextLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textColor = .secondaryLabel
            label.font = UIFont.preferredFont(forTextStyle: .footnote)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 1
            label.textAlignment = .center
            label.lineBreakMode = .byTruncatingTail
            return label
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            contentView.addSubview(imageView)
            contentView.addSubview(textLabel)
            contentView.addSubview(detailTextLabel)

            let layoutGuide = UILayoutGuide()
            contentView.addLayoutGuide(layoutGuide)

            self.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
            NSLayoutConstraint.activate([

                imageView.widthAnchor.constraint(equalToConstant: 48.0),
                imageView.heightAnchor.constraint(equalToConstant: 48.0),

                imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

                textLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                textLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

                detailTextLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                detailTextLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

                imageView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: textLabel.topAnchor, constant: -8.0),
                textLabel.bottomAnchor.constraint(equalTo: detailTextLabel.topAnchor, constant: -2.0),
                detailTextLabel.bottomAnchor.constraint(equalTo: layoutGuide.topAnchor),
                layoutGuide.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),

            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

    }

    static var cell = "Cell"

    var settings: Settings
    var taskManager: TaskManager
    var directory: Directory
    var installer: Installer?
    var applicationActiveObserver: Any?
    var settingsSink: AnyCancellable?

    private func createLayout() -> UICollectionViewLayout {

        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(100), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(108))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.interItemSpacing = .flexible(8.0)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsetsReference = .layoutMargins
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }

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

    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.register(Cell.self, forCellWithReuseIdentifier: Self.cell)
        collectionView.alwaysBounceVertical = true
        collectionView.preservesSuperviewLayoutMargins = true
        collectionView.insetsLayoutMarginsFromSafeArea = true
        return collectionView
    }()

    lazy var dataSource: DataSource = {
        let cellRegistration = UICollectionView.CellRegistration<Cell, Item> { [weak self] cell, _, item in
            guard let self = self else {
                return
            }
            cell.textLabel.text = item.directoryItem.name
            cell.detailTextLabel.text = item.isRunning ? "Running" : nil
            cell.imageView.image = item.directoryItem.icon(for: self.settings.theme).scale(self.view.window?.screen.nativeScale ?? 1.0)
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

    lazy var menuBarButtonItem: UIBarButtonItem = {
        let newFolderAction = UIAction(title: "New Folder",
                                       image: UIImage(systemName: "folder.badge.plus")) { [unowned self] action in
            self.createDirectory()
        }
        let menu = UIMenu(title: "", image: nil, identifier: nil, options: [], children: [newFolderAction])
        let menuBarButtonItem = UIBarButtonItem(title: nil,
                                                image: UIImage(systemName: "ellipsis.circle"),
                                                primaryAction: nil,
                                                menu: menu)
        return menuBarButtonItem
    }()
    
    init(settings: Settings, taskManager: TaskManager, directory: Directory, title: String? = nil) {
        self.settings = settings
        self.taskManager = taskManager
        self.directory = directory
        super.init(nibName: nil, bundle: nil)
        self.directory.delegate = self
        view.backgroundColor = .systemBackground
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        collectionView.backgroundView = wallpaperView
        collectionView.dataSource = dataSource
        self.title = title ?? directory.name
        self.navigationItem.searchController = searchController
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationItem.rightBarButtonItem = menuBarButtonItem
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let notificationCenter = NotificationCenter.default
        applicationActiveObserver = notificationCenter.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                                   object: nil,
                                                                   queue: nil) { notification in
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
        dataSource.apply(snapshot(), animatingDifferences: animated)
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

    let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 48)

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

        let runAsActions = Device.allCases.map { device in
            UIAction(title: device.name) { action in
                let program = Program(settings: self.settings, url: url, device: device)
                let viewController = ProgramViewController(settings: self.settings,
                                                           taskManager: self.taskManager,
                                                           program: program)
                self.navigationController?.pushViewController(viewController, animated: true)
            }
        }
        let runAsMenu = UIMenu(title: "Run As...", children: runAsActions)
        actions.append(runAsMenu)

        if taskManager.isRunning(url) {
            let quitAction = UIAction(title: "Quit") { action in
                self.taskManager.quit(url)
            }
            actions.append(quitAction)
        }

        return actions
    }

    func snapshot() -> Snapshot {
        var snapshot = Snapshot()
        snapshot.appendSections([.none])
        let items = directory.items(filter: searchController.searchBar.text)
            .map { item -> Item in
                var isRunning = false
                if let programUrl = item.programUrl, taskManager.isRunning(programUrl) {
                    isRunning = true
                }
                return Item(directoryItem: item, isRunning: isRunning)
            }
        snapshot.appendItems(items, toSection: nil)
        return snapshot
    }

}

extension DirectoryViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
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
            installer = Installer(url: item.url, fileSystem: SystemFileSystem(rootUrl: item.url.deletingPathExtension()))
            installer?.delegate = self
            installer?.run()
        case .unknown, .applicationInformation:
            break
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let item = configuration.identifier as? NSNumber,
              let itemInt = item as? Int,
              let cell = collectionView.cellForItem(at: IndexPath(item: itemInt, section: 0)) as? Cell else {
            return nil
        }
        return UITargetedPreview(view: cell.imageView)
    }

    func collectionView(_ collectionView: UICollectionView,
                        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let item = configuration.identifier as? NSNumber,
              let itemInt = item as? Int,
              let cell = collectionView.cellForItem(at: IndexPath(item: itemInt, section: 0)) as? Cell else {
            return nil
        }
        return UITargetedPreview(view: cell.imageView)
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath)?.directoryItem else {
            return nil
        }
        return UIContextMenuConfiguration(identifier: indexPath.item as NSNumber, previewProvider: nil) { suggestedActions in
            let deleteAction = UIAction(title: "Delete",
                                         image: UIImage(systemName: "trash"),
                                         attributes: .destructive) { action in
                self.delete(item: item)
            }
            let fileMenu = UIMenu(options: [.displayInline], children: [deleteAction])
            switch item.type {
            case .object, .application:
                let actions = self.actions(for: item.programUrl!)
                return UIMenu(children: actions + [fileMenu])
            case .system:
                let contentsAction = UIAction(title: "Show Package Contents") { action in
                    self.pushDirectoryViewController(for: item.url)
                }
                let actions = self.actions(for: item.programUrl!)
                return UIMenu(children: actions + [contentsAction, fileMenu])
            case .directory, .installer, .unknown, .applicationInformation:
                return UIMenu(children: [fileMenu])
            }
        }
    }

}

extension DirectoryViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        dataSource.apply(snapshot())
    }

}

extension DirectoryViewController: DirectoryDelegate {

    func directoryDidChange(_ directory: Directory) {
        dataSource.apply(snapshot())
    }
}

extension DirectoryViewController: InstallerDelegate {

    func installer(_ installer: Installer, didFinishWithResult result: OpoInterpreter.Result) {
        DispatchQueue.main.async {
            print("installer(\(installer), didFinishWithResult: \(result))")
            switch result {
            case .none:
                let alert = UIAlertController(title: "Installer", message: "Complete!", preferredStyle: .alert)
                alert.addAction(.init(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            case .error(let error):
                self.present(error: error)
            }
            self.reload()
        }
    }

    func installer(_ installer: Installer, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.present(error: error)
            self.reload()
        }
    }

}

extension DirectoryViewController: TaskManagerObserver {

    func taskManagerDidUpdate(_ taskManager: TaskManager) {
        dataSource.apply(snapshot(), animatingDifferences: true)
    }

}
