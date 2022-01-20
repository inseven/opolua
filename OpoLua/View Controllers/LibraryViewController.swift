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

class LibraryViewController: UIViewController {

    enum Section {
        case examples
        case locations
    }

    struct Item: Hashable {

        static func == (lhs: Item, rhs: Item) -> Bool {
            return lhs.location.url == rhs.location.url
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(location.url)
        }

        let location: Location
        let name: String
        let readonly: Bool

        init(location: Location, readonly: Bool = false) {
            self.location = location
            self.name = location.url.name
            self.readonly = readonly
        }

        init(location: Location, name: String, readonly: Bool = false) {
            self.location = location
            self.name = name
            self.readonly = readonly
        }

    }

    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    class LibraryDataSource: UICollectionViewDiffableDataSource<Section, Item> {

//        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//            guard let section = sectionIdentifier(for: section) else {
//                return nil
//            }
//            switch section {
//            case .examples:
//                return "Examples"
//            case .locations:
//                return "Locations"
//            }
//        }

    }

    class HeaderView: UICollectionReusableView {

        lazy var textLabel: UILabel = {
            let label = UILabel()
            label.text = "Cheese"
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            addSubview(textLabel)
            NSLayoutConstraint.activate([
                textLabel.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
                textLabel.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
                textLabel.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
                textLabel.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

    }

    var settings: Settings
    var taskManager: TaskManager
    var dataSource: LibraryDataSource!

    lazy var collectionView: UICollectionView = {

        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.headerMode = .supplementary
        configuration.trailingSwipeActionsConfigurationProvider = { [unowned self] indexPath in
            guard let item = self.dataSource.itemIdentifier(for: indexPath), !item.readonly else {
                return nil
            }
            let action = UIContextualAction(style: .normal, title: "Done!") { action, view, completion in
                deleteLocation(item.location)
                completion(true)
            }
            action.title = "Delete"
            action.backgroundColor = .systemRed
            return UISwipeActionsConfiguration(actions: [action])
        }

        let collectionViewLayout = UICollectionViewCompositionalLayout.list(using: configuration)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self

        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, item in
            var configuration = cell.defaultContentConfiguration()
            configuration.image = UIImage(systemName: "folder")
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
            case .examples:
                configuration.text = "Examples"
            case .locations:
                configuration.text = "Locations"
            }
            supplementaryView.contentConfiguration = configuration
        }

        dataSource = LibraryDataSource(collectionView: collectionView) { collectionView, indexPath, item in
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

        collectionView.alwaysBounceVertical = true
        collectionView.preservesSuperviewLayoutMargins = true
        collectionView.insetsLayoutMarginsFromSafeArea = true
        return collectionView
    }()

    lazy var addBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "plus"),
                                            style: .plain,
                                            target: self,
                                            action: #selector(addTapped(sender:)))
        return barButtonItem
    }()

    lazy var aboutBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(title: "Settings",
                                            style: .plain,
                                            target: self,
                                            action: #selector(settingsTapped(sender:)))
        return barButtonItem
    }()

    init(settings: Settings, taskManager: TaskManager) {
        self.settings = settings
        self.taskManager = taskManager
        super.init(nibName: nil, bundle: nil)
        title = "OPL"
        navigationItem.rightBarButtonItem = addBarButtonItem
        navigationItem.leftBarButtonItem = aboutBarButtonItem
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        dataSource.apply(snapshot(), animatingDifferences: false)
    }

    @objc func settingsTapped(sender: UIBarButtonItem) {
        let viewController = UIHostingController(rootView: SettingsView(settings: settings))
        self.present(viewController, animated: true)
    }

    func reload() {
        self.dataSource.apply(snapshot())
    }

    func snapshot() -> Snapshot {
        var snapshot = Snapshot()
        snapshot.appendSections([.examples, .locations])
        snapshot.appendItems([Item(location: LocalLocation(url: Bundle.main.examplesUrl), readonly: true)],
                             toSection: .examples)
        let locations = settings.locations
            .map { Item(location: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) != .orderedDescending }
        snapshot.appendItems(locations, toSection: .locations)
        return snapshot
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

    func deleteLocation(_ location: Location) {
        guard let location = location as? ExternalLocation else {
            return
        }
        do {
            try settings.removeLocation(location)
            reload()
        } catch {
            present(error: error)
        }
    }

}

extension LibraryViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath), !item.readonly else {
            return nil
        }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            var actions: [UIMenuElement] = []
            let runAction = UIAction(title: "Delete",
                                     image: UIImage(systemName: "trash"),
                                     attributes: [.destructive]) { action in
                self.deleteLocation(item.location)
            }
            actions.append(runAction)
            return UIMenu(children: suggestedActions + actions)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            collectionView.deselectItem(at: indexPath, animated: true)
            return
        }
        do {
            let directory = try Directory(url: item.location.url)
            let viewController = DirectoryViewController(settings: settings,
                                                         taskManager: taskManager,
                                                         directory: directory,
                                                         title: item.name)
            navigationController?.pushViewController(viewController, animated: true)
        } catch {
            present(error: error)
            collectionView.deselectItem(at: indexPath, animated: true)
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
