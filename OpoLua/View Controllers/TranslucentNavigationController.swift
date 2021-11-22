//
//  TranslucentNavigationController.swift
//  OpoLua
//
//  Created by Jason Barrie Morley on 22/11/2021.
//

import UIKit

class TranslucentNavigationController: UINavigationController {

    override func viewDidLoad() {
        view.backgroundColor = .clear
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(blurView, at: 0)
        NSLayoutConstraint.activate([
          blurView.topAnchor.constraint(equalTo: view.topAnchor),
          blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
          blurView.heightAnchor.constraint(equalTo: view.heightAnchor),
          blurView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
    }

}
