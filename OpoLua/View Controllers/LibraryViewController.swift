// Copyright (c) 2021 Jason Morley, Tom Sutcliffe
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

import UIKit
import UniformTypeIdentifiers

protocol DataSourceDelegate: AnyObject {

    func deleteLocation(_ location: Location)

}

class LibraryViewController: UITableViewController {

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

        init(location: Location) {
            self.location = location
            self.name = location.url.name
        }

        init(location: Location, name: String) {
            self.location = location
            self.name = name
        }

    }

    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    class LibraryDataSource: UITableViewDiffableDataSource<Section, Item> {

        weak var delegate: DataSourceDelegate?

        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            guard let section = sectionIdentifier(for: section) else {
                return nil
            }
            switch section {
            case .examples:
                return "Examples"
            case .locations:
                return "Locations"
            }
        }

        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            return true
        }

        override func tableView(_ tableView: UITableView,
                                commit editingStyle: UITableViewCell.EditingStyle,
                                forRowAt indexPath: IndexPath) {
            guard editingStyle == .delete,
                  let item = itemIdentifier(for: indexPath)
            else {
                return
            }
            delegate?.deleteLocation(item.location)
        }

    }

    static let cellIdentifier = "Cell"

    var settings = Settings()
    var dataSource: LibraryDataSource!

    init() {
        super.init(style: .insetGrouped)
        title = "OPL"
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "plus"),
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(addTapped(sender:)))
        tableView.dataSource = nil
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellIdentifier)
        dataSource = LibraryDataSource(tableView: tableView) { tableView, indexPath, itemIdentifier in
            let location = itemIdentifier
            let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)
            cell.textLabel?.text = location.name
            cell.imageView?.image = UIImage(systemName: "folder")
            cell.accessoryType = .disclosureIndicator
            return cell
        }
        dataSource.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        dataSource.apply(snapshot(), animatingDifferences: false)
    }

    func reload() {
        self.dataSource.apply(snapshot())
    }

    func snapshot() -> Snapshot {

        var snapshot = Snapshot()
        snapshot.appendSections([.examples, .locations])

        // Examples

        snapshot.appendItems([Item(location: LocalLocation(url: Bundle.main.examplesUrl))],
                             toSection: .examples)

        // Locations
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        do {
            let directory = try Directory(url: item.location.url)
            let viewController = DirectoryViewController(directory: directory, title: item.name)
            navigationController?.pushViewController(viewController, animated: true)
        } catch {
            present(error: error)
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    func addUrl(_ url: URL) {
        do {
            try settings.addLocation(url)
            reload()
        } catch {
            present(error: error)
        }
    }

}

extension LibraryViewController: DataSourceDelegate {

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
