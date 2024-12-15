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

import Foundation

#if canImport(UIKit)
import UIKit
#endif

protocol RootViewDelegate: AnyObject {

    func rootView(_ rootView: RootView, insertCharacter character: Character)
    func rootViewDeleteBackward(_ rootView: RootView)
    func rootView(_ rootView: RootView, sendKey key: OplKeyCode)

}

class RootView : ViewBase {

#if canImport(UIKit)
    var keyboardType: UIKeyboardType = .asciiCapable
#endif

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

#if canImport(UIKit)
    override var canBecomeFirstResponder: Bool {
#if targetEnvironment(macCatalyst)
        // This is a hack; the reason we refuse first responder status on catalyst is because this prevents the
        // UIKeyInput support from kicking in when we call becomeFirstResponder from Program.textEditor(_:). And the
        // reason we do _that_ is because in that mode, hardware cursor keys events are not passed in. Ideally we'd
        // also want to prevent this on the iPad when a hardware keyboard is being used (which has the same problem)
        // but that's more complicated to achieve -- hence why this is a hack.
        return false
#else
        return true
#endif
    }
#endif

    override var intrinsicContentSize: CGSize {
        return screenSize
    }

    var windows: [CanvasView] {
        return self.subviews.compactMap { view in
            return view as? CanvasView
        }
    }

#if canImport(UIKit)
    private func makeKeyButton(imageName: String, key: OplKeyCode) -> UIButton {
        var config: UIButton.Configuration = .plain()
        config.image = UIImage(systemName: imageName)
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] action in
            guard let self else {
                return
            }
            self.delegate?.rootView(self, sendKey: key)
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    override var inputAccessoryView: UIView? {
        let view = UIView()
        view.tintColor = self.tintColor

        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        effectView.translatesAutoresizingMaskIntoConstraints = false

        var doneButtonConfiguration: UIButton.Configuration = .plain()
        doneButtonConfiguration.title = "Done"
        let doneButton = UIButton(configuration: doneButtonConfiguration, primaryAction: UIAction(handler: { [weak self] action in
            guard let self else {
                return
            }
            self.resignFirstResponder()
        }))
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        let escapeButton = makeKeyButton(imageName: "escape", key: .escape)
        let leftButton = makeKeyButton(imageName: "arrowtriangle.left", key: .leftArrow)
        let upButton = makeKeyButton(imageName: "arrowtriangle.up", key: .upArrow)
        let downButton = makeKeyButton(imageName: "arrowtriangle.down", key: .downArrow)
        let rightButton = makeKeyButton(imageName: "arrowtriangle.right", key: .rightArrow)

        view.addSubview(effectView)
        view.addSubview(escapeButton)
        view.addSubview(leftButton)
        view.addSubview(upButton)
        view.addSubview(downButton)
        view.addSubview(rightButton)
        view.addSubview(doneButton)
        NSLayoutConstraint.activate([

            effectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: view.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            escapeButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            escapeButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            escapeButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),

            leftButton.leadingAnchor.constraint(equalTo: escapeButton.trailingAnchor),
            leftButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            leftButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),

            upButton.leadingAnchor.constraint(equalTo: leftButton.trailingAnchor),
            upButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            upButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),

            downButton.leadingAnchor.constraint(equalTo: upButton.trailingAnchor),
            downButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            downButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),

            rightButton.leadingAnchor.constraint(equalTo: downButton.trailingAnchor),
            rightButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            rightButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),

            doneButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            doneButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            doneButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),

        ])
        view.frame = CGRect(origin: .zero, size: view.systemLayoutSizeFitting(CGSize(width: .max, height: .max)))
        return view
    }

    func screenshot() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: self.frame.size, format: format)
        let uiImage = renderer.image { rendererContext in
            let context = rendererContext.cgContext
            context.setAllowsAntialiasing(false)
            context.interpolationQuality = .none
            self.layer.render(in: context)
        }
        return uiImage
    }
#endif
}

#if canImport(UIKit)

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

#endif
