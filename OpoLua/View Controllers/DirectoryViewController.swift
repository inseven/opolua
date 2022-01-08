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

class DirectoryViewController : UITableViewController {
    
    var directory: Directory
    var installer: Installer?
    
    init(directory: Directory, title: String? = nil) {
        self.directory = directory
        super.init(style: .plain)
        self.title = title ?? directory.name
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = true
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl?.addTarget(self, action: #selector(refresh(sender:)), for: .valueChanged)
    }

    @objc func refresh(sender: UIRefreshControl) {
        reload()
    }

    func reload() {
        do {
            directory = try Directory(url: directory.url)
            tableView.reloadData()
            tableView.refreshControl?.endRefreshing()
        } catch {
            present(error: error)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return directory.objects.count
    }

    let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 48)
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let item = directory.objects[indexPath.row]
        cell.textLabel?.text = item.name
        cell.detailTextLabel?.text = item.type.localizedDescription
        cell.accessoryType = .disclosureIndicator
        switch item.type {
        case .object:
            cell.imageView?.image = UIImage(systemName: "applescript", withConfiguration: symbolConfiguration)
        case .directory:
            cell.imageView?.image = UIImage(named: "FolderIcon")
        case .app:
            cell.imageView?.image = UIImage(systemName: "app", withConfiguration: symbolConfiguration)
        case .bundle(let application):
            if let appIcon = application.appInfo.appIcon {
                cell.imageView?.image = appIcon
            } else {
                cell.imageView?.image = UIImage(systemName: "app", withConfiguration: symbolConfiguration)
            }
        case .system(let application):
            if let appIcon = application.appInfo.appIcon {
                cell.imageView?.image = appIcon
            } else {
                cell.imageView?.image = UIImage(systemName: "app", withConfiguration: symbolConfiguration)
            }
        case .installer:
            cell.imageView?.image = UIImage(systemName: "shippingbox", withConfiguration: symbolConfiguration)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = directory.objects[indexPath.row]
        switch item.type {
        case .object, .app, .bundle, .system:
            guard let configuration = item.configuration else {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
            let program = Program(configuration: configuration)
            let viewController = ProgramViewController(program: program)
            navigationController?.pushViewController(viewController, animated: true)
        case .directory:
            pushDirectoryViewController(for: item.url)
            tableView.deselectRow(at: indexPath, animated: true)
        case .installer:
            installer = Installer(url: item.url, fileSystem: SystemFileSystem(rootUrl: item.url.deletingPathExtension()))
            installer?.delegate = self
            installer?.run()
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

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
        let runAction = UIAction(title: "Run") { action in
            let program = Program(configuration: configuration)
            let viewController = ProgramViewController(program: program)
            self.navigationController?.pushViewController(viewController, animated: true)
        }
        let runAsActions = Device.allCases.map { device in
            UIAction(title: device.name) { action in
                let program = Program(configuration: configuration, device: device)
                let viewController = ProgramViewController(program: program)
                self.navigationController?.pushViewController(viewController, animated: true)
            }
        }
        let runAsMenu = UIMenu(title: "Run As...", children: runAsActions)
        let procedureActions = configuration.procedures.map { procedure in
            UIAction(title: procedure.name) { action in
                let program = Program(configuration: configuration, procedureName: procedure.name)
                let viewController = ProgramViewController(program: program)
                self.navigationController?.pushViewController(viewController, animated: true)
            }
        }
        let procedureMenu = UIMenu(title: "Procedures", children: procedureActions)
        return [runAction, runAsMenu, procedureMenu]
    }

    override func tableView(_ tableView: UITableView,
                            contextMenuConfigurationForRowAt indexPath: IndexPath,
                            point: CGPoint) -> UIContextMenuConfiguration? {
        let item = directory.objects[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            let deleteActions = UIAction(title: "Delete", attributes: .destructive) { action in
                do {
                    try FileManager.default.removeItem(at: item.url)
                    self.reload()
                } catch {
                    self.present(error: error)
                }
            }
            switch item.type {
            case .object, .app:
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
