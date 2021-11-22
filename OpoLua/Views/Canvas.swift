//
//  Canvas.swift
//  OpoLua
//
//  Created by Jason Barrie Morley on 22/11/2021.
//

import UIKit

class Canvas: UIView {

    let screenSize: CGSize

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerPixel = 4

    lazy var buffer: Data = {
        return Data(count: Int(screenSize.width) * Int(screenSize.height) * bytesPerPixel)
    }()

    init(screenSize: CGSize) {
        self.screenSize = screenSize
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
        let bytesPerRow = bytesPerPixel * Int(screenSize.width)
        let bitsPerComponent = 8
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        buffer.withUnsafeMutableBytes { data in
            let context = CGContext(data: data.baseAddress,
                                    width: Int(screenSize.width),
                                    height: Int(screenSize.height),
                                    bitsPerComponent: bitsPerComponent,
                                    bytesPerRow: bytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: bitmapInfo)!
            for operation in operations {
                context.draw(operation)
            }
            self.imageView.image = UIImage(cgImage: context.makeImage()!)
        }
    }

}
