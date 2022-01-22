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

import SwiftUI
import UIKit
import UniformTypeIdentifiers

protocol LibraryViewControllerDelegate: AnyObject {

    func libraryViewController(_ libraryViewController: LibraryViewController, presentViewController viewController: UIViewController)

}

class LibraryViewController: UICollectionViewController {

    enum Section {
        case special
        case examples
        case locations
    }

    enum ItemType: Hashable {

        case runningPrograms  // TODO: RENAME
        case allPrograms
        case local(URL)
        case external(SecureLocation)

    }

    struct Item: Hashable {

        static func == (lhs: Item, rhs: Item) -> Bool {
            return lhs.type == rhs.type
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(type)
        }

        let type: ItemType
        let name: String
        let image: UIImage
        let readonly: Bool

        var url: URL? {
            switch type {
            case .runningPrograms:
                return nil
            case .allPrograms:
                return nil
            case .local(let url):
                return url
            case .external(let location):
                return location.url
            }
        }

        init(type: ItemType, name: String, image: UIImage, readonly: Bool = false) {
            self.type = type
            self.name = name
            self.image = image
            self.readonly = readonly
        }

    }

    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>

    var settings: Settings
    var taskManager: TaskManager
    var dataSource: DataSource!
    var delegate: LibraryViewControllerDelegate?

    lazy var addBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "plus"),
                                            style: .plain,
                                            target: self,
                                            action: #selector(addTapped(sender:)))
        return barButtonItem
    }()

    lazy var aboutBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "gear"),
                                            style: .plain,
                                            target: self,
                                            action: #selector(settingsTapped(sender:)))
        return barButtonItem
    }()

    init(settings: Settings, taskManager: TaskManager) {
        self.settings = settings
        self.taskManager = taskManager
        super.init(collectionViewLayout: UICollectionViewCompositionalLayout.list(using: UICollectionLayoutListConfiguration(appearance: .insetGrouped)))
        title = "OPL"
        navigationItem.rightBarButtonItem = addBarButtonItem
        navigationItem.leftBarButtonItem = aboutBarButtonItem

        collectionView.collectionViewLayout = makeLayout()

        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, item in
            var configuration = cell.defaultContentConfiguration()
            configuration.image = item.image
            configuration.text = item.name
            cell.contentConfiguration = configuration
            cell.accessories = [UICellAccessory.disclosureIndicator()]
        }

        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) {
            supplementaryView, string, indexPath in
            guard let section = self.dataSource.sectionIdentifier(for: indexPath.section) else {
                return
            }
            var configuration = UIListContentConfiguration.extraProminentInsetGroupedHeader()
            switch section {
            case .special:
                configuration.text = nil
            case .examples:
                configuration.text = "Examples"
            case .locations:
                configuration.text = "Locations"
            }
            supplementaryView.contentConfiguration = configuration
        }

        dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        dataSource.supplementaryViewProvider = { collectionView, elementKind, indexPath in
            if elementKind == UICollectionView.elementKindSectionHeader {
                return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
            }
            else {
                return nil
            }
        }

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        dataSource.apply(snapshot(), animatingDifferences: animated)
    }

    @objc func settingsTapped(sender: UIBarButtonItem) {
        let viewController = UIHostingController(rootView: SettingsView(settings: settings))
        self.present(viewController, animated: true)
    }

    func reload() {
        dataSource.apply(snapshot())
    }

    func snapshot() -> Snapshot {
        var snapshot = Snapshot()
        snapshot.appendSections([.special, .examples])
        snapshot.appendItems([Item(type: .runningPrograms,
                                   name: "Running Programs",
                                   image: UIImage(systemName: "play.square")!),
                             Item(type: .allPrograms,
                                   name: "All Programs",
                                   image: UIImage(systemName: "square")!)],
                             toSection: .special)
        snapshot.appendItems([Item(type: .local(Bundle.main.bundleURL),
                                   name: "Files",
                                   image: UIImage(systemName: "folder")!,
                                   readonly: true),
                              Item(type: .local(Bundle.main.examplesUrl),
                                   name: "Scripts",
                                   image: UIImage(systemName: "folder")!,
                                   readonly: true)],
                             toSection: .examples)
        let locations = settings.locations
            .map { Item(type: .external($0), name: $0.url.name, image: UIImage(systemName: "folder")!) }
            .sorted { $0.name.localizedStandardCompare($1.name) != .orderedDescending }
        if locations.count > 0 {
            snapshot.appendSections([.locations])
            snapshot.appendItems(locations, toSection: .locations)
        }
        return snapshot
    }

    func makeLayout() -> UICollectionViewLayout {
        let appearance: UICollectionLayoutListConfiguration.Appearance = (splitViewController?.isCollapsed ?? true) ? .insetGrouped : .sidebar
        var configuration = UICollectionLayoutListConfiguration(appearance: appearance)
        configuration.headerMode = .supplementary
        configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self = self,
                  let item = self.dataSource.itemIdentifier(for: indexPath),
                  !item.readonly else {
                return nil
            }
            let action = UIContextualAction(style: .normal, title: "Done!") { action, view, completion in
                if case .external(let location) = item.type {
                    self.deleteLocation(location)
                }
                completion(true)
            }
            action.title = "Delete"
            action.backgroundColor = .systemRed
            return UISwipeActionsConfiguration(actions: [action])
        }
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }

    @objc func addTapped(sender: UIBarButtonItem) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        documentPicker.delegate = self
        present(documentPicker, animated: true)
    }

    func addUrl(_ url: URL) {
        do {
            try settings.addLocation(url)
            reload()
        } catch {
            present(error: error)
        }
    }

    // TODO: Consider just passing in the item here.
    func deleteLocation(_ location: SecureLocation) {
        do {
            try settings.removeLocation(location)
            reload()
        } catch {
            present(error: error)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        collectionView.collectionViewLayout = makeLayout()
    }

    override func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath), !item.readonly else {
            return nil
        }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            var actions: [UIMenuElement] = []
            let deleteAction = UIAction(title: "Delete",
                                        image: UIImage(systemName: "trash"),
                                        attributes: [.destructive]) { action in
                if case .external(let location) = item.type {
                    self.deleteLocation(location)
                }
            }
            actions.append(deleteAction)
            return UIMenu(children: suggestedActions + actions)
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            collectionView.deselectItem(at: indexPath, animated: true)
            return
        }
        switch item.type {
        case .runningPrograms:
            let viewController = UIViewController(nibName: nil, bundle: nil)
            viewController.view.backgroundColor = .systemBackground
            viewController.navigationItem.largeTitleDisplayMode = .never
            viewController.title = "Running Programs"
            delegate?.libraryViewController(self, presentViewController: viewController)
        case .allPrograms:
            let viewController = UIViewController(nibName: nil, bundle: nil)
            viewController.view.backgroundColor = .systemBackground
            viewController.navigationItem.largeTitleDisplayMode = .never
            viewController.title = "All Programs"
            delegate?.libraryViewController(self, presentViewController: viewController)
        case .local, .external:
            do {
                guard let url = item.url else {
                    return
                }
                let directory = try Directory(url: url)
                let viewController = DirectoryViewController(settings: settings,
                                                             taskManager: taskManager,
                                                             directory: directory,
                                                             title: item.name)
                delegate?.libraryViewController(self, presentViewController: viewController)
            } catch {
                present(error: error)
                collectionView.deselectItem(at: indexPath, animated: true)
            }
        }
    }

}

extension LibraryViewController: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            addUrl(url)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        addUrl(url)
    }

}
