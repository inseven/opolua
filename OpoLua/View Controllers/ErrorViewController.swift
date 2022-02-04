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

protocol ErrorViewControllerDelegate: AnyObject {

    func errorViewControllerDidFinish(_ errorViewController: ErrorViewController)

}

class ErrorViewController: UIViewController {

    var error: Error

    weak var delegate: ErrorViewControllerDelegate?

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    // Maybe better as a selectable label?
    lazy var textView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        textView.preservesSuperviewLayoutMargins = true
        textView.isScrollEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13.0, weight: .regular)
        return textView
    }()

    lazy var doneBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                            target: self,
                                            action: #selector(doneTapped(sender:)))
        return barButtonItem
    }()

    lazy var shareBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(barButtonSystemItem: .action,
                                            target: self,
                                            action: #selector(actionTapped(sender:)))
        return barButtonItem
    }()

    init(error: Error, screenshot: UIImage) {
        self.error = error
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .systemBackground
        isModalInPresentation = true
        title = "Error Details"
        navigationItem.leftBarButtonItem = shareBarButtonItem
        navigationItem.rightBarButtonItem = doneBarButtonItem

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.preservesSuperviewLayoutMargins = true
        scrollView.alwaysBounceVertical = true

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .equalCentering
        stackView.spacing = UIStackView.spacingUseSystem

        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(textView)

        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            // Preserve the aspect ratio of the screenshot.
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor,
                                             multiplier: screenshot.size.width / screenshot.size.height),
        ])

        textView.text = error.localizedDescription
        if let interpreterError = error as? OpoInterpreter.InterpreterError {
            textView.text += "\n" + interpreterError.message
            textView.text += "\n" + interpreterError.detail
        }
        imageView.image = screenshot
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func doneTapped(sender: UIBarButtonItem) {
        delegate?.errorViewControllerDidFinish(self)
    }

    @objc func actionTapped(sender: UIBarButtonItem) {
        guard let text = textView.text else {
            return
        }
        let activityViewController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        self.present(activityViewController, animated: true)
    }

}

extension ErrorViewController: ConsoleDelegate {

    func console(_ console: Console, didAppendLine line: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.textView.text.append(line)
    }

}
