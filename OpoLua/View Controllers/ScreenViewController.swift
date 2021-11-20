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
        // TODO
        return "123" // Have to return something valid here otherwise INPUT might keep on asking us
    }
    
    func alert(lines: [String], buttons: [String]) -> Int {
        let semaphore = DispatchSemaphore(value: 0)
        var result = 1
        DispatchQueue.main.async {
            let message = lines.joined(separator: "\n")
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            if buttons.count > 0 {
                for (index, button) in buttons.enumerated() {
                    alert.addAction(.init(title: button, style: .default) { action in
                        result = index + 1
                        semaphore.signal()
                    })
                }
            } else {
                alert.addAction(.init(title: "Continue", style: .default) { action in
                    semaphore.signal()
                })
            }
            self.present(alert, animated: true, completion: nil)
        }
        semaphore.wait()
        return result
    }
    
    func getch() -> Int {
        return 0
    }
    
    func beep(frequency: Double, duration: Double) {
        print("BEEP")
    }

    func dialog(_ d: Dialog) -> Int {
        // TODO
        return 0
    }

}
