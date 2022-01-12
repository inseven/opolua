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

import Foundation
import UIKit
import SwiftUI

class DirectoryViewController : UIViewController {

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
            return label
        }()

        lazy var detailTextLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textColor = .secondaryLabel
            label.font = UIFont.preferredFont(forTextStyle: .footnote)
            label.adjustsFontForContentSizeCategory = true
            return label
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(imageView)
            self.addSubview(textLabel)
            self.addSubview(detailTextLabel)

            let layoutGuide = UILayoutGuide()
            addLayoutGuide(layoutGuide)

            self.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
            NSLayoutConstraint.activate([

                imageView.widthAnchor.constraint(equalToConstant: 48.0),
                imageView.heightAnchor.constraint(equalToConstant: 48.0),

                imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                textLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                detailTextLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

                imageView.topAnchor.constraint(equalTo: topAnchor),
                imageView.bottomAnchor.constraint(equalTo: textLabel.topAnchor, constant: -8.0),
                textLabel.bottomAnchor.constraint(equalTo: detailTextLabel.topAnchor, constant: -2.0),
                detailTextLabel.bottomAnchor.constraint(equalTo: layoutGuide.topAnchor),
                layoutGuide.bottomAnchor.constraint(equalTo: bottomAnchor),

            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

    }

    static var cell = "Cell"
    
    var directory: Directory
    var items: [Directory.Item] = []
    var installer: Installer?
    var applicationActiveObserver: Any?

    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.33),
                                             heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .fractionalWidth(0.33))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }

    lazy var wallpaperView: UIView = {
        let image = UIImage.epoc
        let pixelView = PixelView(image: image)
        pixelView.translatesAutoresizingMaskIntoConstraints = false
        pixelView.backgroundColor = .clear
        let view = UIView(frame: .zero)
        view.addSubview(pixelView)
        NSLayoutConstraint.activate([
            pixelView.widthAnchor.constraint(equalToConstant: image.size.width),
            pixelView.heightAnchor.constraint(equalToConstant: image.size.height),
            pixelView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pixelView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view
    }()

    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(Cell.self, forCellWithReuseIdentifier: Self.cell)
        collectionView.alwaysBounceVertical = true
        return collectionView
    }()

    lazy var searchController: UISearchController = {
        let searchController = UISearchController()
        searchController.searchResultsUpdater = self
        return searchController
    }()

    lazy var menuBarButtonItem: UIBarButtonItem = {
        let newFolderAction = UIAction(title: "New Folder", image: UIImage(systemName: "folder.badge.plus")) { action in
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
        let menu = UIMenu(title: "", image: nil, identifier: nil, options: [], children: [newFolderAction])
        let menuBarButtonItem = UIBarButtonItem(title: nil,
                                                image: UIImage(systemName: "ellipsis.circle"),
                                                primaryAction: nil,
                                                menu: menu)
        return menuBarButtonItem
    }()
    
    init(directory: Directory, title: String? = nil) {
        self.directory = directory
        self.items = directory.items
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
        navigationController?.isToolbarHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applicationActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                                           object: nil,
                                                                           queue: nil) { notification in
            self.reload()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let observer = applicationActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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
            let viewController = DirectoryViewController(directory: directory)
            navigationController?.pushViewController(viewController, animated: true)
        } catch {
            present(error: error)
        }
    }

    func actions(for configuration: Program.Configuration) -> [UIMenuElement] {
        var actions: [UIMenuElement] = []

        let runAction = UIAction(title: "Run") { action in
            let program = Program(configuration: configuration)
            let viewController = ProgramViewController(program: program)
            self.navigationController?.pushViewController(viewController, animated: true)
        }
        actions.append(runAction)

        let runAsActions = Device.allCases.map { device in
            UIAction(title: device.name) { action in
                let program = Program(configuration: configuration, device: device)
                let viewController = ProgramViewController(program: program)
                self.navigationController?.pushViewController(viewController, animated: true)
            }
        }
        let runAsMenu = UIMenu(title: "Run As...", children: runAsActions)
        actions.append(runAsMenu)

        return actions
    }

}

extension DirectoryViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.cell, for: indexPath) as! Cell
        let item = items[indexPath.row]
        cell.textLabel.text = item.name
        cell.detailTextLabel.text = item.type.localizedDescription
        cell.imageView.image = item.icon.scale(view.window?.screen.nativeScale ?? 1.0)
        return cell
    }

}

extension DirectoryViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        switch item.type {
        case .object, .app, .bundle, .system:
            guard let configuration = item.configuration else {
                return
            }
            let program = Program(configuration: configuration)
            let viewController = ProgramViewController(program: program)
            navigationController?.pushViewController(viewController, animated: true)
        case .directory:
            pushDirectoryViewController(for: item.url)
        case .installer:
            installer = Installer(url: item.url, fileSystem: SystemFileSystem(rootUrl: item.url.deletingPathExtension()))
            installer?.delegate = self
            installer?.run()
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
        let item = items[indexPath.row]
        return UIContextMenuConfiguration(identifier: indexPath.item as NSNumber, previewProvider: nil) { suggestedActions in
            let deleteActions = UIAction(title: "Delete", attributes: .destructive) { action in
                do {
                    try FileManager.default.removeItem(at: item.url)
                    self.reload()
                } catch {
                    self.present(error: error)
                }
            }
            switch item.type {
            case .object:
                guard let configuration = item.configuration else {
                    return nil
                }
                let actions = self.actions(for: configuration)
                let procedureActions = configuration.procedures.map { procedure in
                    UIAction(title: procedure.name) { action in
                        let program = Program(configuration: configuration, procedureName: procedure.name)
                        let viewController = ProgramViewController(program: program)
                        self.navigationController?.pushViewController(viewController, animated: true)
                    }
                }
                let procedureMenu = UIMenu(title: "Procedures", children: procedureActions)
                return UIMenu(children: actions + [procedureMenu, deleteActions])
            case .app:
                guard let configuration = item.configuration else {
                    return nil
                }
                let actions = self.actions(for: configuration)
                return UIMenu(children: actions + [deleteActions])
            case .bundle, .system:
                guard let configuration = item.configuration else {
                    return nil
                }
                let contentsAction = UIAction(title: "Show Package Contents") { action in
                    self.pushDirectoryViewController(for: item.url)
                }
                let actions = self.actions(for: configuration)
                return UIMenu(children: actions + [contentsAction, deleteActions])
            case .directory:
                return UIMenu(children: [deleteActions])
            case .installer:
                return UIMenu(children: [deleteActions])
            }
        }
    }

}

extension DirectoryViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        items = directory.items(filter: searchController.searchBar.text)
        collectionView.reloadData()
    }

}

extension DirectoryViewController: DirectoryDelegate {

    func directoryDidChange(_ directory: Directory) {
        items = directory.items(filter: searchController.searchBar.text)
        collectionView.reloadData()
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
