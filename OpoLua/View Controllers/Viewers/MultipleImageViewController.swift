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

class MultipleImageViewController: UITableViewController {

    class Cell: UITableViewCell {

        static var reuseIdentifier = "Cell"

        lazy var bitmapView: UIImageView = {
            let imageView = UIImageView(frame: .zero)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
            return imageView
        }()

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            contentView.addSubview(bitmapView)

            let leadingGuide = UILayoutGuide()
            let trailingGuide = UILayoutGuide()
            let topGuide = UILayoutGuide()
            let bottomGuide = UILayoutGuide()

            contentView.addLayoutGuide(leadingGuide)
            contentView.addLayoutGuide(trailingGuide)
            contentView.addLayoutGuide(topGuide)
            contentView.addLayoutGuide(bottomGuide)

            NSLayoutConstraint.activate([

                leadingGuide.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
                trailingGuide.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
                topGuide.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
                bottomGuide.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),

                bitmapView.leadingAnchor.constraint(equalTo: leadingGuide.trailingAnchor),
                bitmapView.trailingAnchor.constraint(equalTo: trailingGuide.leadingAnchor),
                bitmapView.topAnchor.constraint(equalTo: topGuide.bottomAnchor),
                bitmapView.bottomAnchor.constraint(equalTo: bottomGuide.topAnchor),
                bitmapView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                bitmapView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

    }

    private let url: URL
    private var isLoaded = false
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
        tableView.register(Cell.self, forCellReuseIdentifier: Cell.reuseIdentifier)
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
        let interpreter = OpoInterpreter()
        let item = try Directory.item(for: url, interpreter: interpreter)
        switch item.type {
        case .applicationInformation(let applicationMetadata):
            guard let applicationMetadata = applicationMetadata else {
                throw OpoLuaError.unsupportedFile
            }
            let bitmaps = applicationMetadata.icons
            self.images = bitmaps
                .compactMap { $0.cgImage }
                .compactMap { UIImage(cgImage: $0) }
            tableView.reloadData()
        case .image:
            let bitmaps = OpoInterpreter().getMbmBitmaps(path: url.path) ?? []
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
        return images.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Cell.reuseIdentifier, for: indexPath) as! Cell
        cell.bitmapView.image = images[indexPath.row]
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200.0
    }

}
