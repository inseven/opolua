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

import UIKit

protocol DestinationPickerViewControllerDelegate: AnyObject {

    func destinationPickerViewControllerDidCancel(_ destinationPickerViewController: DestinationPickerViewController)
    func destinationPickerViewController(_ destinationPickerViewController: DestinationPickerViewController,
                                         didSelectUrl url: URL)

}

class DestinationPickerViewController: UITableViewController {

    static let reuseIdentifier = "Cell"

    let urls: [URL]
    let selectedUrl: URL
    weak var delegate: DestinationPickerViewControllerDelegate?

    lazy var cancelBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(title: "Cancel",
                                            style: .plain,
                                            target: self,
                                            action: #selector(cancelTapped(sender:)))
        return barButtonItem
    }()

    init(urls: [URL], selectedUrl: URL) {
        self.urls = urls
        self.selectedUrl = selectedUrl
        super.init(style: .plain)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.reuseIdentifier)
        navigationItem.rightBarButtonItem = cancelBarButtonItem
        title = "Destination"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func cancelTapped(sender: UIBarButtonItem) {
        delegate?.destinationPickerViewControllerDidCancel(self)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return urls.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.reuseIdentifier, for: indexPath)
        let url = urls[indexPath.row]
        cell.textLabel?.text = url.localizedName
        cell.accessoryType = url == selectedUrl ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let url = urls[indexPath.row]
        delegate?.destinationPickerViewController(self, didSelectUrl: url)
    }
}
