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

import OpoLuaCore

class ResourceViewController: UITableViewController {

    class StringCell: UITableViewCell {

        static var reuseIdentifier = "StringCell"

        override init(style: CellStyle, reuseIdentifier: String?) {
            super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

    }

    class ImageCell: UITableViewCell {

        static var reuseIdentifier = "ImageCell"

        lazy var bitmapView: UIImageView = {
            let imageView = UIImageView(frame: .zero)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            return imageView
        }()

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            contentView.addSubview(bitmapView)

            NSLayoutConstraint.activate([
                bitmapView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
                bitmapView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
                bitmapView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
                bitmapView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

    }

    struct NamedString {

        let name: String
        let value: String

    }

    private let url: URL
    private var isLoaded = false
    private var strings: [NamedString] = []
    private var images: [UIImage] = []

    lazy var shareBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(barButtonSystemItem: .action,
                                            target: self,
                                            action: #selector(shareTapped(sender:)))
        return barButtonItem
    }()

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
        title = url.localizedName
        tableView.register(ImageCell.self, forCellReuseIdentifier: ImageCell.reuseIdentifier)
        tableView.register(StringCell.self, forCellReuseIdentifier: StringCell.reuseIdentifier)
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        navigationItem.rightBarButtonItem = shareBarButtonItem
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

    func load() throws {
        guard !isLoaded else {
            return
        }
        isLoaded = true
        let interpreter = PsiLuaEnv()
        let item = try Directory.item(for: url, env: interpreter)
        switch item.type {
        case .applicationInformation(let applicationMetadata):
            guard let applicationMetadata = applicationMetadata else {
                throw OpoLuaError.unsupportedFile
            }
            self.strings = [NamedString(name: "UID3",
                                        value: String(applicationMetadata.uid3, radix: 16))]
            self.strings += applicationMetadata.captions.map({ localizedString in
                return NamedString(name: "Caption (\(localizedString.locale.identifier))", value: localizedString.value)
            })
            let bitmaps = applicationMetadata.icons
            self.images = bitmaps
                .compactMap { $0.cgImage }
                .compactMap { UIImage(cgImage: $0) }
            tableView.reloadData()
        case .image:
            let bitmaps = interpreter.getMbmBitmaps(path: url.path) ?? []
            self.images = bitmaps
                .compactMap { CGImage.from(bitmap: $0) }
                .compactMap { UIImage(cgImage: $0) }
            tableView.reloadData()
        default:
            throw OpoLuaError.unsupportedFile
        }
    }

    @objc func shareTapped(sender: UIBarButtonItem) {
        let activityViewController = UIActivityViewController(activityItems: self.images, applicationActivities: nil)
        self.present(activityViewController, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return strings.count + images.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.row < strings.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: StringCell.reuseIdentifier, for: indexPath)
            let string = strings[indexPath.row]
            cell.textLabel?.text = string.name
            cell.detailTextLabel?.text = string.value
            cell.selectionStyle = .none
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: ImageCell.reuseIdentifier,
                                                     for: indexPath) as! ImageCell
            cell.bitmapView.image = images[indexPath.row - strings.count]
            cell.selectionStyle = .none
            return cell
        }
    }

}
