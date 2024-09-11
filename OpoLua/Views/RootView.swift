// Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe
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

import OpoLuaCore

protocol RootViewDelegate: AnyObject {

    func rootView(_ rootView: RootView, insertCharacter character: Character)
    func rootViewDeleteBackward(_ rootView: RootView)
    func rootView(_ rootView: RootView, sendKey key: OplKeyCode)

}

class RootView : UIView {

    var keyboardType: UIKeyboardType = .asciiCapable

    let screenSize: CGSize
    weak var delegate: RootViewDelegate?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(screenSize: CGSize) {
        self.screenSize = screenSize
        super.init(frame: CGRect(origin: .zero, size: screenSize))
        self.translatesAutoresizingMaskIntoConstraints = false
        self.clipsToBounds = true
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override var intrinsicContentSize: CGSize {
        return screenSize
    }

    override var inputAccessoryView: UIView? {
        let view = UIView()
        view.tintColor = self.tintColor

        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        effectView.translatesAutoresizingMaskIntoConstraints = false

        var doneButtonConfiguration: UIButton.Configuration = .plain()
        doneButtonConfiguration.title = "Done"
        let doneButton = UIButton(configuration: doneButtonConfiguration, primaryAction: UIAction(handler: { [weak self] action in
            guard let self = self else {
                return
            }
            self.resignFirstResponder()
        }))
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        var escapeButtonConfiguration: UIButton.Configuration = .plain()
        escapeButtonConfiguration.image = UIImage(systemName: "escape")
        let escapeButton = UIButton(configuration: escapeButtonConfiguration, primaryAction: UIAction { [weak self] action in
            guard let self = self else {
                return
            }
            self.delegate?.rootView(self, sendKey: .escape)
        })
        escapeButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(effectView)
        view.addSubview(escapeButton)
        view.addSubview(doneButton)
        NSLayoutConstraint.activate([

            effectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: view.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            escapeButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            escapeButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            escapeButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),

            doneButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            doneButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            doneButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),

        ])
        view.frame = CGRect(origin: .zero, size: view.systemLayoutSizeFitting(CGSize(width: .max, height: .max)))
        return view
    }

}

extension RootView: UIKeyInput {

    var hasText: Bool {
        return true
    }

    func insertText(_ text: String) {
        for character in text {
            delegate?.rootView(self, insertCharacter: character)
        }
    }

    func deleteBackward() {
        delegate?.rootViewDeleteBackward(self)
    }

}
