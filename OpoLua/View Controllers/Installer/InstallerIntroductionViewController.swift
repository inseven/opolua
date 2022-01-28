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

class Value1TableViewCell: UITableViewCell {

    override init(style: CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

protocol InstallerIntroductionViewControllerDelegate: AnyObject {

    func installerIntroductionViewController(_ installerIntroductionViewController: InstallerIntroductionViewController, continueWithDestinationUrl destinationUrl: URL)
    func installerIntroductionViewControllerDidCancel(_ installerIntroductionViewController: InstallerIntroductionViewController)

}

// TODO: Observe the theme.
class InstallerIntroductionViewController: UIViewController {

    static let reuseIdentifier = "Cell"

    var destinationUrl: URL
    var delegate: InstallerIntroductionViewControllerDelegate?

    lazy var cancelBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(title: "Cancel",
                                            style: .plain,
                                            target: self,
                                            action: #selector(cancelTapped(sender:)))
        return barButtonItem
    }()

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = .installerIconC
        // TODO: Make this change colour with the theme.
        return imageView
    }()

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "Install"
        return label
    }()

    lazy var detailTextLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .title2)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "Clicking 'Continue' will install the package into the selected destination.\n\nInstalled scripts and programs are sandboxed and cannot access files outisde of their own directory."
        label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        return label
    }()

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(Value1TableViewCell.self, forCellReuseIdentifier: Self.reuseIdentifier)
        tableView.backgroundColor = .systemBackground
        tableView.dataSource = self
        tableView.delegate = self
        return tableView
    }()

    lazy var continueButton: UIButton = {
        var configuration: UIButton.Configuration = .borderedProminent()
        configuration.buttonSize = .large
        configuration.title = "Next"
        configuration.cornerStyle = .large
        let buttonView = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] action in
            guard let self = self else {
                return
            }
            self.delegate?.installerIntroductionViewController(self, continueWithDestinationUrl: self.destinationUrl)
        })
        buttonView.translatesAutoresizingMaskIntoConstraints = false
        buttonView.preservesSuperviewLayoutMargins = true
        return buttonView
    }()

    lazy var headerView: UIView = {
        let headerView = UIView()
        headerView.addSubview(imageView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(detailTextLabel)
        headerView.preservesSuperviewLayoutMargins = true
        NSLayoutConstraint.activate([

            imageView.widthAnchor.constraint(equalToConstant: 48.0),
            imageView.heightAnchor.constraint(equalToConstant: 48.0),

            imageView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.trailingAnchor),

            detailTextLabel.leadingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.leadingAnchor),
            detailTextLabel.trailingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.trailingAnchor),

            imageView.topAnchor.constraint(equalTo: headerView.layoutMarginsGuide.topAnchor),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8.0),
            detailTextLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8.0),
            detailTextLabel.bottomAnchor.constraint(equalTo: headerView.layoutMarginsGuide.bottomAnchor),
        ])
        headerView.frame = CGRect(origin:.zero,
                                  size: headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize))
        return headerView
    }()

    init(destinationUrl: URL) {
        print("destination = \(destinationUrl)")
        self.destinationUrl = destinationUrl
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = cancelBarButtonItem
        navigationItem.hidesBackButton = true
        view.addSubview(tableView)
        view.addSubview(continueButton)
        tableView.tableHeaderView = headerView

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            continueButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            continueButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            continueButton.topAnchor.constraint(equalTo: tableView.bottomAnchor),
            continueButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let systemLayoutSize = headerView.systemLayoutSizeFitting(CGSize(width: tableView.frame.size.width, height: 100000))
        headerView.frame = CGRect(origin: .zero, size: systemLayoutSize)
        tableView.setNeedsLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { context in
            let systemLayoutSize = self.headerView.systemLayoutSizeFitting(CGSize(width: size.width, height: 100000))
            self.headerView.frame = CGRect(origin: .zero, size: systemLayoutSize)
        } completion: { context in

        }
    }

    @objc func cancelTapped(sender: UIBarButtonItem) {
        delegate?.installerIntroductionViewControllerDidCancel(self)
    }

}

extension InstallerIntroductionViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.reuseIdentifier, for: indexPath)
        cell.textLabel?.text = "Destination"
        cell.detailTextLabel?.text = "Current Folder"
        cell.backgroundColor = .secondarySystemBackground
        return cell
    }

}

extension InstallerIntroductionViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

}
