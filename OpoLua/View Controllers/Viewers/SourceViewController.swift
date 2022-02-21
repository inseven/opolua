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

protocol SourceViewControllerDelelgate: AnyObject {

    func sourceViewControllerDidFinish(_ sourceViewController: SourceViewController)

}

class SourceViewController: UIViewController {

    private var url: URL
    private var isLoaded = false

    weak var delegate: SourceViewControllerDelelgate?

    lazy var textView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.preservesSuperviewLayoutMargins = false
        textView.font = .monospacedSystemFont(ofSize: 14.0, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        textView.alwaysBounceVertical = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0.0
        return textView
    }()

    lazy var shareBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(barButtonSystemItem: .action,
                                            target: self,
                                            action: #selector(shareTapped(sender:)))
        return barButtonItem
    }()

    init(url: URL, showsDoneButton: Bool = false) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
        title = url.localizedName
        view.backgroundColor = .systemBackground
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        if showsDoneButton {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                                target: self,
                                                                action: #selector(doneTapped(sender:)))
            navigationItem.leftBarButtonItem = shareBarButtonItem
        } else {
            navigationItem.rightBarButtonItem = shareBarButtonItem
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            try load()
        } catch {
            present(error: error)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateTextContainerInsets()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTextContainerInsets()
    }

    @objc func doneTapped(sender: UIBarButtonItem) {
        delegate?.sourceViewControllerDidFinish(self)
    }

    @objc func shareTapped(sender: UIBarButtonItem) {
        guard let text = textView.text else {
            return
        }
        let activityViewController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        self.present(activityViewController, animated: true)
    }

    func load() throws {
        guard !isLoaded else {
            return
        }
        isLoaded = true
        let interpreter = OpoInterpreter()
        let item = try Directory.item(for: url, interpreter: interpreter)
        var contents: String
        switch item.type {
        case .text:
            contents = try String(contentsOf: url)
        case .opl:
            let fileInfo = interpreter.getFileInfo(path: url.path)
            guard case OpoInterpreter.FileInfo.opl(let opoFile) = fileInfo else {
                throw OpoLuaError.unsupportedFile
            }
            contents = opoFile.text
        default:
            throw OpoLuaError.unsupportedFile
        }
        textView.text = contents
    }

    func updateTextContainerInsets() {
        // Unfortunately this doesn't seem to be automatic (probably holding it wrong), so we update the text container
        // insets manually to have them match our view's layout margins / safe areas. Even more unpleasant is the fact
        // that the UITextView seems to be honouring the vertical safe areas, but not the horizontal safe areas so we
        // actually have to account for that when we create the insets.
        textView.textContainerInset = UIEdgeInsets(top: view.layoutMargins.top - view.safeAreaInsets.top,
                                                   left: view.layoutMargins.left,
                                                   bottom: view.layoutMargins.bottom - view.safeAreaInsets.bottom,
                                                   right: view.layoutMargins.right)
    }

}
