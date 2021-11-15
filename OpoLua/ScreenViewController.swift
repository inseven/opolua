//
//  ScreenViewController.swift
//  OpoLua
//
//  Created by Tom Sutcliffe on 15/11/2021.
//

import UIKit

class ScreenViewController: UIViewController {
    var textView: UITextView!
    let opo = OpoInterpreter()

    init() {
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .systemGroupedBackground
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        opo.run(file: Bundle.main.path(forResource: "simple", ofType: "opo")!)
    }

}
