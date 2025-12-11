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

class IconCollectionViewCell: UICollectionViewCell {

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .clear

        imageView.layer.shadowColor = CGColor(gray: 1.0, alpha: 1.0)
        imageView.layer.shadowOpacity = 1.0
        imageView.layer.shadowRadius = 0.0
        imageView.clipsToBounds = false
        imageView.layer.shadowOffset = CGSize(width: 0.5, height: 0.5)

        return imageView
    }()

    lazy var textLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    lazy var detailTextLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabel
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        contentView.addSubview(textLabel)
        contentView.addSubview(detailTextLabel)

        let layoutGuide = UILayoutGuide()
        contentView.addLayoutGuide(layoutGuide)

        self.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        NSLayoutConstraint.activate([

            imageView.widthAnchor.constraint(equalToConstant: 48.0),
            imageView.heightAnchor.constraint(equalToConstant: 48.0),

            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            textLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            textLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            detailTextLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            detailTextLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            imageView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: textLabel.topAnchor, constant: -8.0),
            textLabel.bottomAnchor.constraint(equalTo: detailTextLabel.topAnchor, constant: -2.0),
            detailTextLabel.bottomAnchor.constraint(equalTo: layoutGuide.topAnchor),
            layoutGuide.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),

        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
