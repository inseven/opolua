// Copyright (c) 2021-2023 Jason Morley, Tom Sutcliffe
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

class RunningProgramsViewController : UICollectionViewController {

    enum Section {
        case none
    }

    struct Item: Hashable {

        static func == (lhs: RunningProgramsViewController.Item, rhs: RunningProgramsViewController.Item) -> Bool {
            if lhs.title != rhs.title {
                return false
            }
            if lhs.icon != rhs.icon {
                return false
            }
            if lhs.isRunning != rhs.isRunning {
                return false
            }
            if lhs.program.url != rhs.program.url {
                return false
            }
            if lhs.program.title != rhs.program.title {
                return false
            }
            return true
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            hasher.combine(program.url)
            hasher.combine(icon)
            hasher.combine(isRunning)
        }

        var title: String
        var icon: Icon
        var isRunning: Bool
        var program: Program
    }

    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias Cell = IconCollectionViewCell

    static var cell = "Cell"

    var settings: Settings
    var taskManager: TaskManager
    var installer: Installer?
    var settingsSink: AnyCancellable?

    override var canBecomeFirstResponder: Bool {
        return true
    }

    lazy var dataSource: DataSource = {
        let cellRegistration = UICollectionView.CellRegistration<Cell, Item> { [weak self] cell, _, item in
            guard let self = self else {
                return
            }
            cell.textLabel.text = item.title
            cell.detailTextLabel.text = item.isRunning ? "Running" : nil
            cell.imageView.image = item.icon.image(for: self.settings.theme).scale(self.view.window?.screen.nativeScale ?? 1.0)
        }
        let dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        return dataSource
    }()

    lazy var placeholderView: UIView = {

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: .title1)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.text = "No Running Programs"

        let view = UIView(frame: .zero)
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -16.0),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, constant: -16.0),
        ])

        return view
    }()

    init(settings: Settings, taskManager: TaskManager) {
        self.settings = settings
        self.taskManager = taskManager
        super.init(collectionViewLayout: IconCollectionViewLayout())
        collectionView.backgroundColor = UIColor(named: "DirectoryBackground")
        collectionView.preservesSuperviewLayoutMargins = true
        collectionView.insetsLayoutMarginsFromSafeArea = true
        collectionView.dataSource = dataSource
        collectionView.backgroundView = placeholderView
        title = "Running Programs"
        navigationItem.largeTitleDisplayMode = .never
        update(animated: false)
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
            self.update(animated: true)
        }
        taskManager.addObserver(self)
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
        taskManager.removeObserver(self)
    }

    private func update(animated: Bool) {
        collectionView.backgroundView?.isHidden = taskManager.programs.count > 0
        var snapshot = Snapshot()
        snapshot.appendSections([.none])
        let items = taskManager.programs.map { program in
            return Item(title: program.title, icon: program.icon, isRunning: true, program: program)
        }
        snapshot.appendItems(items, toSection: Section.none)
        dataSource.apply(snapshot, animatingDifferences: animated)
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            collectionView.deselectItem(at: indexPath, animated: true)
            return
        }
        let viewController = ProgramViewController(settings: settings, taskManager: taskManager, program: item.program)
        navigationController?.pushViewController(viewController, animated: true)
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
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }
        return UIContextMenuConfiguration(identifier: indexPath.item as NSNumber, previewProvider: nil) { suggestedActions in
            let actions = self.taskManager.actions(for: item.program.url)
            return UIMenu(children: actions)
        }
    }

}

extension RunningProgramsViewController: TaskManagerObserver {

    func taskManagerDidUpdate(_ taskManager: TaskManager) {
        update(animated: true)
    }

}
