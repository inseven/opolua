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
    
    var object: OPLObject
    
    var state: State = .idle
    let opo = OpoInterpreter()
    let runtimeQueue = DispatchQueue(label: "ScreenViewController.runtimeQueue")
    
    var getCompletion: ((Int) -> Void)? {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            menuBarButtonItem.isEnabled = (getCompletion != nil)
        }
    }
    
    lazy var textView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    lazy var menuBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "filemenu.and.selection"),
                                            style: .plain,
                                            target: self,
                                            action: #selector(menuTapped(sender:)))
        return barButtonItem
    }()

    init(object: OPLObject) {
        self.object = object
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .systemBackground
        navigationItem.title = object.name
        
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),
        ])
        
        setToolbarItems([menuBarButtonItem], animated: false)
        menuBarButtonItem.isEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = false
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
        let object = self.object
        print(object.procedures ?? [])
        runtimeQueue.async {
            self.opo.iohandler = self
            self.opo.run(file: object.url.path)
        }
    }
    
    @objc func menuTapped(sender: UIBarButtonItem) {
        getCompletion?(KeyCode.menu.rawValue)
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
        let semaphore = DispatchSemaphore(value: 0)
        var keyCode = 0
        DispatchQueue.main.async {
            self.getCompletion = { result in
                keyCode = result
                self.getCompletion = nil
                semaphore.signal()
            }
        }
        semaphore.wait()
        return keyCode
    }
    
    func beep(frequency: Double, duration: Double) {
        print("BEEP")
    }

    func dialog(_ d: Dialog) -> Dialog.Result {
        // TODO
        return Dialog.Result(result: 0, values: [])
    }

    func menu(_ menu: Menu.Bar) -> Menu.Result {
        let semaphore = DispatchSemaphore(value: 0)
        var result = Menu.Result(selected: 0, highlighted: 0) // TODO: .none
        DispatchQueue.main.async {
            let viewController = MenuBarViewController(bar: menu) { item in
                if let item = item {
                    result = Menu.Result(selected: item.keycode, highlighted: 0)
                }
                semaphore.signal()
            }
            let navigationController = UINavigationController(rootViewController: viewController)
            if #available(iOS 15.0, *) {
                if let presentationController = navigationController.presentationController
                    as? UISheetPresentationController {
                    presentationController.detents = [.medium(), .large()]
                }
            }
            self.present(navigationController, animated: true)
        }
        semaphore.wait()
        return result
    }

    func draw(ops: [GraphicsOperation]) {
        // TODO
    }

}
