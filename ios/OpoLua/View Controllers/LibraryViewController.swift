// Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe
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
import UIKit
import UniformTypeIdentifiers

protocol LibraryViewControllerDelegate: AnyObject {

    func libraryViewController(_ libraryViewController: LibraryViewController, showSection section: ApplicationSection)

}

class LibraryViewController: UICollectionViewController {

    enum Section {
        case special
        case examples
        case locations
    }

    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, ApplicationSection>
    typealias DataSource = UICollectionViewDiffableDataSource<Section, ApplicationSection>

    private var settings: Settings
    private var taskManager: TaskManager
    private var detector: ProgramDetector
    private var dataSource: DataSource!
    private var settingsSink: AnyCancellable?
    private var section: ApplicationSection? = .allPrograms

    weak var delegate: LibraryViewControllerDelegate?

    private lazy var addBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "folder.badge.plus"),
                                            style: .plain,
                                            target: self,
                                            action: #selector(addTapped(sender:)))
        return barButtonItem
    }()

    private lazy var settingsBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "gear"),
                                            style: .plain,
                                            target: self,
                                            action: #selector(settingsTapped(sender:)))
        return barButtonItem
    }()

    init(settings: Settings, taskManager: TaskManager, detector: ProgramDetector) {
        self.settings = settings
        self.taskManager = taskManager
        self.detector = detector
        super.init(collectionViewLayout: UICollectionViewCompositionalLayout.list(using: UICollectionLayoutListConfiguration(appearance: .insetGrouped)))
        title = "Library"
        navigationItem.rightBarButtonItem = addBarButtonItem
#if !targetEnvironment(macCatalyst)
        navigationItem.leftBarButtonItem = settingsBarButtonItem
#endif
        clearsSelectionOnViewWillAppear = false

        collectionView.collectionViewLayout = createLayout()

        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, ApplicationSection> { [weak self] cell, _, item in
            guard let self = self else {
                return
            }
            var configuration = cell.defaultContentConfiguration()
            configuration.image = item.image
            configuration.text = item.name
            cell.contentConfiguration = configuration

            var accessories: [UICellAccessory] = []
            if item == .runningPrograms && taskManager.programs.count > 0 {
                let badgeLabel = UILabel()
                badgeLabel.text = String(taskManager.programs.count)
                badgeLabel.textColor = UIColor.secondaryLabel
                let viewConfig = UICellAccessory.CustomViewConfiguration(customView: badgeLabel,
                                                                         placement: .trailing(displayed: .always))
                let badgeAccessory = UICellAccessory.customView(configuration: viewConfig)
                accessories.append(badgeAccessory)
            }
            if self.isCollapsedInSplitView {
                accessories.append(UICellAccessory.disclosureIndicator())
            }
            cell.accessories = accessories
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

        taskManager.addObserver(self)
        reload(animated: false)
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
            self.reload(animated: animated)
        }
        if let section = section {
            selectSection(section: section, animated: false)
            if isCollapsedInSplitView {
                collectionView.indexPathsForSelectedItems?.forEach { indexPath in
                    collectionView.deselectItem(at: indexPath, animated: true)
                }
                self.section = nil
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        dataSource.apply(snapshot(), animatingDifferences: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        settingsSink = nil
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        settingsSink = nil
    }

    @objc func settingsTapped(sender: UIBarButtonItem) {
        let viewController = UIHostingController(rootView: SettingsView(settings: settings))
        self.present(viewController, animated: true)
    }

    func selectSection(section: ApplicationSection, animated: Bool = true) {
        guard let indexPath = dataSource.indexPath(for: section) else {
            return
        }
        self.section = section
        collectionView.selectItem(at: indexPath, animated: animated, scrollPosition: .centeredVertically)
    }

    func reload(animated: Bool) {
        dataSource.apply(snapshot(), animatingDifferences: animated)
    }

    func reconfigureItems(_ items: [ApplicationSection], animated: Bool) {
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(items)
        dataSource.apply(snapshot, animatingDifferences: animated)
    }

    func snapshot() -> Snapshot {
        var snapshot = Snapshot()
        snapshot.appendSections([.special])
        snapshot.appendItems([.allPrograms, .runningPrograms, .documents], toSection: .special)

        // Examples
        var examples: [ApplicationSection] = []
        if settings.showLibraryFiles {
            examples.append(.local(Bundle.main.filesUrl))
        }
        if settings.showLibraryScripts {
            examples.append(.local(Bundle.main.scriptsUrl))
        }
        if settings.showLibraryTests {
            examples.append(.local(Bundle.main.testsUrl))
        }
        if examples.count > 0 {
            snapshot.appendSections([.examples])
            snapshot.appendItems(examples, toSection: .examples)
        }

        let locations = settings.locations
            .map { ApplicationSection.external($0) }
            .sorted { $0.name.localizedStandardCompare($1.name) != .orderedDescending }
        if locations.count > 0 {
            snapshot.appendSections([.locations])
            snapshot.appendItems(locations, toSection: .locations)
        }

        return snapshot
    }

    func createLayout() -> UICollectionViewLayout {
        let appearance: UICollectionLayoutListConfiguration.Appearance = isCollapsedInSplitView ? .insetGrouped : .sidebar
        var configuration = UICollectionLayoutListConfiguration(appearance: appearance)
        configuration.headerMode = .supplementary
        configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self = self,
                  let item = self.dataSource.itemIdentifier(for: indexPath),
                  !item.isReadOnly else {
                return nil
            }
            let action = UIContextualAction(style: .destructive, title: nil) { action, view, completion in
                if case .external(let location) = item {
                    self.deleteLocation(location)
                }
                completion(true)
            }
            if #available(iOS 26, *) {
                action.image = UIImage(systemName: "trash")
            } else {
                action.title = "Remove"
            }
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
        dispatchPrecondition(condition: .onQueue(.main))

        let perform: () -> Void = {
            do {
                try self.settings.addLocation(url)
                self.reload(animated: true)
            } catch {
                self.present(error: error)
            }
        }

        // Show a warning when adding iCloud Drive locations to ensure the user understand that we'll download all the
        // folder contents, giving them the option to select a directory with fewer contents.
        if FileManager.default.isUbiquitousItem(at: url) {

            let alertController = UIAlertController(title: "iCloud Drive",
                                                    message: "OPL automatically downloads files from iCloud Drive to ensure they are available to running programs.\n\nThis can cause increased disk usage when adding large folders.",
                                                    preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Continue", style: .default) { action in
                perform()
            })
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alertController, animated: true)

        } else {
            perform()
        }
    }

    func deleteLocation(_ location: URL) {
        do {
            try settings.removeLocation(location)
            reload(animated: true)
        } catch {
            present(error: error)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        collectionView.collectionViewLayout = createLayout()
        var snapshot = dataSource.snapshot()
        snapshot.reloadSections(snapshot.sectionIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            collectionView.deselectItem(at: indexPath, animated: true)
            return
        }
        section = item
        delegate?.libraryViewController(self, showSection: item)
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

extension LibraryViewController: TaskManagerObserver {

    func taskManagerDidUpdate(_ taskManager: TaskManager) {
        reconfigureItems([.runningPrograms], animated: false)
    }

}
