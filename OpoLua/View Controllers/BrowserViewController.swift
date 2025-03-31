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

import UIKit

import PsionSoftwareIndex

class BrowserViewController: UICollectionViewController {

#if DEBUG

    internal lazy var addBarButtonItem: UIBarButtonItem = {
        let softwareIndexAction = UIAction(title: "Psion Software Index",
                                           image: UIImage(systemName: "list.dash.header.rectangle")) { [weak self] action in
            self?.showSoftwareIndex()
        }
        let addFolderAction = UIAction(title: "Add Folder",
                                       image: UIImage(systemName: "folder.badge.plus")) { [weak self] action in
            self?.addFolder()
        }
        let localActionsMenu = UIMenu(options: [.displayInline], children: [softwareIndexAction])
        let remoteActionsMenu = UIMenu(options: [.displayInline], children: [addFolderAction])
        let actions = [
            localActionsMenu,
            remoteActionsMenu,
        ]
        let menu = UIMenu(title: "", image: nil, identifier: nil, options: [], children: actions)
        let addBarButtonItem = UIBarButtonItem(title: nil,
                                               image: UIImage(systemName: "plus"),
                                               primaryAction: nil,
                                               menu: menu)
        return addBarButtonItem
    }()

#else

    internal lazy var addBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "plus"),
                               style: .plain,
                               target: self,
                               action: #selector(addFolder))
    }()

#endif

    internal var settings: Settings

    init(collectionViewLayout: UICollectionViewLayout, settings: Settings) {
        self.settings = settings
        super.init(collectionViewLayout: collectionViewLayout)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static let blockedUIDs: Set<String> = [
        "0x1000af86",  // Strip Poker
    ]

    @objc func showSoftwareIndex() {
        let indexViewController = PsionSoftwareIndexViewController { release in
#if RELEASE
            guard !Self.blockedUIDs.contains(release.uid) else {
                return false
            }
#endif
            return release.kind == .installer && release.hasDownload && release.tags.contains("opl")
        }
        indexViewController.delegate = self
        present(indexViewController, animated: true)
    }

    @objc
    func addFolder() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        documentPicker.delegate = self
        present(documentPicker, animated: true)
    }

    func addUrl(_ url: URL) {
        dispatchPrecondition(condition: .onQueue(.main))

        let perform: () -> Void = {
            do {
                try self.settings.addLocation(url)
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


}

extension BrowserViewController: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            addUrl(url)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        addUrl(url)
    }

}

extension BrowserViewController: PsionSoftwareIndexViewControllerDelegate {

    func psionSoftwareIndexViewCntrollerDidCancel(psionSoftwareIndexViewController: PsionSoftwareIndexViewController) {
        psionSoftwareIndexViewController.dismiss(animated: true)
    }

    func psionSoftwareIndexViewController(psionSoftwareIndexViewController: PsionSoftwareIndexViewController,
                                          didSelectItem item: SoftwareIndexView.Item) {
        psionSoftwareIndexViewController.dismiss(animated: true) {
            AppDelegate.shared.install(url: item.url, sourceUrl: item.sourceURL)
        }
    }

}
