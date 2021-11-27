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

class BorderedButton: UIButton {

    enum Style {
        case gray
    }

    var style: Style

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        if #available(iOS 15.0, *) {
            switch style {
            case .gray:
                configuration = .gray()
            }
        } else {
            layer.cornerRadius = 8.0
            clipsToBounds = true
            switch style {
            case .gray:
                updateAppearance()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateAppearance() {
        if #available(iOS 15.0, *) {
            return
        }
        guard
            let color = UIColor(named: "GrayButtonColor"),
            let highlightColor = UIColor(named: "GrayButtonHighlightColor")
        else {
            return
        }
        setBackgroundImage(UIImage.image(color: color, size: .unit), for: .normal)
        setBackgroundImage(UIImage.image(color: highlightColor, size: .unit), for: .highlighted)
        setTitleColor(tintColor, for: .normal)
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        updateAppearance()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAppearance()
    }

}
