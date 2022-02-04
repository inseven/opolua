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

import UIKit

protocol InstallerSummaryViewControllerDelegate: AnyObject {

    func installerSummaryViewController(_ installerSummaryViewController: InstallerSummaryViewController,
                                        didFinishWithResult result: Result<Void, Error>)

}

class InstallerSummaryViewController: UIViewController {

    var state: Result<Void, Error>

    weak var delegate: InstallerSummaryViewControllerDelegate?

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
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

    init(state: Result<Void, Error>) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .systemBackground
        navigationItem.hidesBackButton = true
        view.addSubview(imageView)
        view.addSubview(label)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 100),
            imageView.heightAnchor.constraint(equalToConstant: 100),
            label.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor),
        ])

        view.addSubview(footerView)
        NSLayoutConstraint.activate([
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        switch state {
        case .success:
            imageView.image = UIImage(systemName: "checkmark.circle")
            imageView.tintColor = .systemGreen
            label.text = "Success!"
        case .failure(let error):
            imageView.image = UIImage(systemName: "xmark.circle")
            imageView.tintColor = .systemRed
            label.text = error.localizedDescription
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
