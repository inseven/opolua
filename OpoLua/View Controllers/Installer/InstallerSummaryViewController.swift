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

import UIKit

protocol InstallerSummaryViewControllerDelegate: AnyObject {

    func installerSummaryViewController(_ installerSummaryViewController: InstallerSummaryViewController,
                                        didFinishWithResult result: Installer.Result)

}

class InstallerSummaryViewController: UIViewController {

    var settings: Settings
    var state: Installer.Result

    weak var delegate: InstallerSummaryViewControllerDelegate?

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .largeTitle)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .body)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    lazy var continueButton: UIButton = {
        let buttonView = UIButton(configuration: .primaryWizardButton(title: "Done"),
                                  primaryAction: UIAction { [weak self] action in
            guard let self = self else {
                return
            }
            self.delegate?.installerSummaryViewController(self, didFinishWithResult: self.state)
        })
        buttonView.translatesAutoresizingMaskIntoConstraints = false
        return buttonView
    }()

    lazy var footerView: UIStackView = {
        let footerView = WizardFooterView()
        footerView.translatesAutoresizingMaskIntoConstraints = false
        footerView.addArrangedSubview(continueButton)
        return footerView
    }()

    init(settings: Settings, state: Installer.Result) {
        self.settings = settings
        self.state = state
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .systemBackground
        navigationItem.hidesBackButton = true
        view.addSubview(imageView)
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 48),
            imageView.heightAnchor.constraint(equalToConstant: 48),
            titleLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            imageView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            titleLabel.topAnchor.constraint(equalToSystemSpacingBelow: imageView.bottomAnchor, multiplier: 1),
            descriptionLabel.topAnchor.constraint(equalToSystemSpacingBelow: titleLabel.bottomAnchor, multiplier: 1),
        ])

        view.addSubview(footerView)
        NSLayoutConstraint.activate([
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        switch state {
        case .success(let item):
            imageView.image = item?.icon.image(for: settings.theme) ?? UIImage(systemName: "checkmark.circle")
            imageView.tintColor = .systemGreen
            titleLabel.text = "Finished"
            if let item = item {
                descriptionLabel.text = "Successfully installed '\(item.name)'."
            }
        case .failure(let error):
            imageView.image = UIImage(systemName: "xmark.circle")
            imageView.tintColor = .systemRed
            titleLabel.text = "Failed"
            descriptionLabel.text = error.localizedDescription
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
