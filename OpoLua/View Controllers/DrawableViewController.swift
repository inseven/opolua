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

import GameController
import UIKit

protocol DrawableViewControllerDelegate: AnyObject {

    func drawableViewControllerDidFinish(_ drawableViewController: DrawableViewController)

}

class DrawableViewController: UIViewController {

    class DrawableCell: UITableViewCell {

        lazy var drawableView: UIImageView = {
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
            imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            return imageView
        }()

        lazy var identifierLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.setContentHuggingPriority(.defaultHigh, for: .vertical)
            label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
            label.textAlignment = .center
            return label
        }()

        lazy var sizeLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.setContentHuggingPriority(.defaultHigh, for: .vertical)
            label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
            label.textAlignment = .center
            return label
        }()

        lazy var modeLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.setContentHuggingPriority(.defaultHigh, for: .vertical)
            label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
            label.textAlignment = .center
            return label
        }()

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            contentView.addSubview(drawableView)
            contentView.addSubview(identifierLabel)
            contentView.addSubview(sizeLabel)
            contentView.addSubview(modeLabel)
            let layoutGuide = UILayoutGuide()
            contentView.addLayoutGuide(layoutGuide)
            NSLayoutConstraint.activate([

                drawableView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
                drawableView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),

                identifierLabel.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
                identifierLabel.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),

                sizeLabel.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
                sizeLabel.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),

                modeLabel.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
                modeLabel.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),

                drawableView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
                drawableView.bottomAnchor.constraint(equalTo: identifierLabel.topAnchor),  // TODO: Plus constant
                identifierLabel.bottomAnchor.constraint(equalTo: sizeLabel.topAnchor),  // Padding?
                sizeLabel.bottomAnchor.constraint(equalTo: modeLabel.topAnchor),
                modeLabel.bottomAnchor.constraint(equalTo: layoutGuide.topAnchor),
                layoutGuide.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

    }

    static var drawableCell = "DrawableCell"

    var windowServer: WindowServer
    weak var delegate: DrawableViewControllerDelegate?

    lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(DrawableCell.self, forCellReuseIdentifier: Self.drawableCell)
        return tableView
    }()

    lazy var doneBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                            target: self,
                                            action: #selector(doneTapped(sender:)))
        return barButtonItem
    }()

    init(windowServer: WindowServer) {
        self.windowServer = windowServer
        super.init(nibName: nil, bundle: nil)
        title = "Drawables"
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        navigationItem.rightBarButtonItem = doneBarButtonItem
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func doneTapped(sender: UIBarButtonItem) {
        delegate?.drawableViewControllerDidFinish(self)
    }

}

extension DrawableViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return windowServer.drawables.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.drawableCell, for: indexPath) as! DrawableCell
        let drawable = windowServer.drawables[indexPath.row]
        let cgImage = drawable.getImage()!
        cell.drawableView.image = UIImage(cgImage: cgImage)
        cell.identifierLabel.text = "#\(drawable.id.value)"
        cell.sizeLabel.text = "\(cgImage.width) x \(cgImage.height)"
        cell.modeLabel.text = drawable.mode.localizedDescription
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120.0
    }

}

extension DrawableViewController: UITableViewDelegate {

}
