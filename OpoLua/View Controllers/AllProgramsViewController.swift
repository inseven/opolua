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
import UIKit

class AllProgramsViewController : BrowserViewController {

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

    private var taskManager: TaskManager
    private var detector: ProgramDetector
    private var items: [Directory.Item] = []
    private var settingsSink: AnyCancellable?

    override var canBecomeFirstResponder: Bool {
        return true
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

    init(settings: Settings, taskManager: TaskManager, detector: ProgramDetector) {
        self.taskManager = taskManager
        self.detector = detector
        super.init(collectionViewLayout: IconCollectionViewLayout(), settings: settings)
        collectionView.preservesSuperviewLayoutMargins = true
        collectionView.insetsLayoutMarginsFromSafeArea = true
        collectionView.backgroundView = wallpaperView
        collectionView.dataSource = dataSource
        title = "All Programs"
        navigationItem.rightBarButtonItem = addBarButtonItem
        navigationItem.largeTitleDisplayMode = .never
        configureRefreshControl()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureRefreshControl() {
#if !targetEnvironment(macCatalyst)
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshControlDidChange(_:)), for: .valueChanged)
        collectionView.refreshControl = refreshControl
#endif
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settingsSink = settings.objectWillChange.sink { [weak self] _ in
            guard let self = self else {
                return
            }
            self.updateWallpaper()
            self.update(animated: true)
        }
        taskManager.addObserver(self)
        detector.delegate = self
        updateWallpaper()
        navigationController?.setToolbarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        update(animated: animated)
        becomeFirstResponder()
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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateWallpaper()
    }

    @objc func refreshControlDidChange(_ sender: UIRefreshControl) {
        detector.update()
        AppDelegate.shared.downloader.update()
    }

    func updateWallpaper() {
        wallpaperPixelView.image = self.settings.theme.wallpaper
        wallpaperPixelView.isHidden = !settings.showWallpaper(in: traitCollection.userInterfaceStyle)
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
        items = detector.items.sorted(by: Directory.defaultSort())
        var snapshot = Snapshot()
        snapshot.appendSections([.none])
        let items = items.map { item -> Item in
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
        case .unknown, .applicationInformation, .sound, .help, .directory, .installer, .image, .text, .opl:
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

                let fileActions: [UIMenuElement] = [UIAction(title: "Show in Library",
                                                            image: UIImage(systemName: "magnifyingglass")) { action in
                    AppDelegate.shared.showUrl(item.url.deletingLastPathComponent())
                }]
                actions += [UIMenu(options: [.displayInline], children: fileActions)]

                return UIMenu(children: actions)
            case .directory, .installer, .unknown, .applicationInformation, .image, .sound, .help, .text, .opl:
                return nil
            }
        }
    }

}

extension AllProgramsViewController: TaskManagerObserver {

    func taskManagerDidUpdate(_ taskManager: TaskManager) {
        update(animated: true)
    }

}

extension AllProgramsViewController: ProgramDetectorDelegate {

    func programDetectorDidUpdateItems(_ programDetector: ProgramDetector) {
        dispatchPrecondition(condition: .onQueue(.main))
        collectionView.refreshControl?.endRefreshing()
        update(animated: true)
    }

    func programDetector(_ programDetector: ProgramDetector, didFailWithError error: Error) {
        dispatchPrecondition(condition: .onQueue(.main))
        collectionView.refreshControl?.endRefreshing()
        present(error: error)
    }

}
