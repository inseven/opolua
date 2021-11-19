//
//  ScreenViewController.swift
//  OpoLua
//
//  Created by Tom Sutcliffe on 15/11/2021.
//

import UIKit

class ScreenViewController: UIViewController {
    
    enum State {
        case idle
        case running
    }
    
    var url: URL
    
    var state: State = .idle
    let opo = OpoInterpreter()
    let runtimeQueue = DispatchQueue(label: "ScreenViewController.runtimeQueue")
    
    lazy var textView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .systemGroupedBackground
        navigationItem.title = FileManager.default.displayName(atPath: url.path)
        
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        start()
    }
    
    func start() {
        guard state == .idle else {
            return
        }
        state = .running
        let url = self.url
        runtimeQueue.async {
            self.opo.iohandler = self
            self.opo.run(file: url.path)
        }
    }

}

extension ScreenViewController: OpoIoHandler {
    
    func printValue(_ val: String) {
        DispatchQueue.main.async {
            self.textView.text?.append(val)
        }
    }
    
    func readLine(escapeShouldErrorEmptyInput: Bool) -> String? {
        return ""
    }
    
    func alert(lines: [String], buttons: [String]) -> Int {
        return 1
    }
    
    func getch() -> Int {
        return 0
    }
    
    func beep(frequency: Double, duration: Double) {
        
    }
        
}
