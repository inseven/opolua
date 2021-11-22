//
//  Canvas.swift
//  OpoLua
//
//  Created by Jason Barrie Morley on 22/11/2021.
//

import UIKit

class Canvas: UIView {

    let screenSize = CGSize(width: 640, height: 240)

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    init() {
        super.init(frame: .zero)
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
        ])
        imageView.image = .emptyImage(with: screenSize)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func draw(_ operations: [Graphics.Operation]) {
        let renderer = UIGraphicsImageRenderer(size: screenSize)
        let image = renderer.image { context in
            context.cgContext.draw(self.imageView.image!.cgImage!, in: CGRect(origin: .zero, size: imageView.image!.size))
            for operation in operations {
                context.cgContext.draw(operation)
            }
        }
        self.imageView.image = image
    }

}
