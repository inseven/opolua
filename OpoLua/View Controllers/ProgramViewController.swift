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

import Combine
import GameController
import UIKit

class ProgramViewController: UIViewController {

    enum ControllerButton: CaseIterable {
        case up
        case down
        case left
        case right
        case a
        case b
        case home
        case options
        case menu
    }

    static let defaultControllerButtonMap: [ControllerButton: OplKeyCode] = [
        .up: .upArrow,
        .down: .downArrow,
        .left: .leftArrow,
        .right: .rightArrow,
        .a: .enter,
        .b: .escape,
        .menu: .menu,
    ]

    static let controllerButtonMaps: [UID: [ControllerButton: OplKeyCode]] = [
        .asteroids: [
            .left: .N,
            .right: .M,
            .a: .space, // Fire
            .b: .Z, // Thrust
            .menu: .menu,
        ],
        .jumpy: [
            .up: .upArrow,
            .down: .downArrow,
            .left: .leftArrow,
            .right: .rightArrow,
            .a: .q, // Jump
            .b: .enter,
            .menu: .menu,
        ],
    ]

    var controllerButtonMap: [ControllerButton: OplKeyCode] {
        guard let uid3 = program.uid3,
              let controllerButtonMap = Self.controllerButtonMaps[uid3]
        else {
            return Self.defaultControllerButtonMap
        }
        return controllerButtonMap
    }

    var settings: Settings
    var taskManager: TaskManager
    var program: Program

    private var screenView: UIView
    private var virtualController: GCVirtualController?
    private var settingsSink: AnyCancellable?

    lazy var controllerState: [ControllerButton: Bool] = {
        return ControllerButton.allCases.reduce(into: [ControllerButton: Bool]()) { partialResult, button in
            partialResult[button] = false
        }
    }()

    lazy var menuButton: UIButton = {
        let button = UIButton(type: .roundedRect)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setBackgroundImage(UIImage(systemName: "filemenu.and.selection"), for: .normal)
        button.addAction(UIAction() { [weak self] action in
            guard let self = self else {
                return
            }
            self.program.sendKey(.menu)
        }, for: .touchUpInside)
        return button
    }()

    lazy var clipboardButton: UIButton = {
        let button = UIButton(type: .roundedRect)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setBackgroundImage(UIImage(systemName: "doc.on.clipboard"), for: .normal)
        button.addAction(UIAction() { [weak self] action in
            guard let self = self else {
                return
            }
            self.program.sendKey(.clipboardSoftkey)
        }, for: .touchUpInside)
        return button
    }()

    lazy var zoomInButton: UIButton = {
        let button = UIButton(type: .roundedRect)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setBackgroundImage(UIImage(systemName: "plus.magnifyingglass"), for: .normal)
        button.addAction(UIAction() { [weak self] action in
            guard let self = self else {
                return
            }
            self.program.sendKey(.zoomInSoftkey)
        }, for: .touchUpInside)
        return button
    }()

    lazy var zoomOutButton: UIButton = {
        let button = UIButton(type: .roundedRect)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setBackgroundImage(UIImage(systemName: "minus.magnifyingglass"), for: .normal)
        button.addAction(UIAction() { [weak self] action in
            guard let self = self else {
                return
            }
            self.program.sendKey(.zoomOutSoftkey)
        }, for: .touchUpInside)
        return button
    }()

    lazy var optionsBarButtonItem: UIBarButtonItem = {
        let quitAction = UIAction(title: "Close Program", image: UIImage(systemName: "xmark")) { [weak self] action in
            guard let self = self else {
                return
            }
            self.program.sendQuit()
        }
        let taskManagerAction = UIAction(title: "Show Open Programs",
                                         image: UIImage(systemName: "list.bullet.rectangle")) { [weak self] action in
            guard let self = self else {
                return
            }
            self.taskManager.showTaskList()
        }
        let consoleAction = UIAction(title: "Show Console", image: UIImage(systemName: "terminal")) { [weak self] action in
            guard let self = self else {
                return
            }
            self.showConsole()
        }
        let drawablesAction = UIAction(title: "Show Drawables",
                                       image: UIImage(systemName: "rectangle.stack")) { [weak self] action in
            guard let self = self else {
                return
            }
            let viewController = DrawableViewController(windowServer: self.program.windowServer)
            viewController.delegate = self
            let navigationController = UINavigationController(rootViewController: viewController)
            self.present(navigationController, animated: true)
        }

        let actions = [quitAction, taskManagerAction, consoleAction, drawablesAction]

        let menu = UIMenu(title: "", image: nil, identifier: nil, options: [], children: actions)
        let menuBarButtonItem = UIBarButtonItem(title: nil,
                                                image: UIImage(systemName: "ellipsis.circle"),
                                                primaryAction: nil,
                                                menu: menu)
        return menuBarButtonItem
    }()

    lazy var keyboardBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "keyboard"),
                                            style: .plain,
                                            target: self,
                                            action: #selector(keyboardTapped(sender:)))
        return barButtonItem
    }()

    lazy var controllerBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "gamecontroller"),
                                            style: .plain,
                                            target: self,
                                            action: #selector(controllerButtonTapped(sender:)))
        return barButtonItem
    }()

    init(settings: Settings, taskManager: TaskManager, program: Program) {
        self.settings = settings
        self.taskManager = taskManager
        self.program = program
        self.screenView = UIView(frame: CGRect(origin: .zero, size: program.getScreenInfo().0.cgSize()))
        super.init(nibName: nil, bundle: nil)
        program.delegate = self
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground

        screenView.translatesAutoresizingMaskIntoConstraints = false
        screenView.addSubview(program.rootView)

        title = program.title
        view.clipsToBounds = true
        screenView.addSubview(menuButton)
        screenView.addSubview(clipboardButton)
        screenView.addSubview(zoomInButton)
        screenView.addSubview(zoomOutButton)

        let silkScreenButtonWidth = 24.0
        let silkScreenButtonHorizontalSpacing = 8.0
        let silkScreenButtonVerticalSpacing = 16.0
        let gutterWidth = silkScreenButtonWidth + silkScreenButtonHorizontalSpacing

        view.addSubview(screenView)
        NSLayoutConstraint.activate([

            program.rootView.centerXAnchor.constraint(equalTo: screenView.centerXAnchor),
            program.rootView.centerYAnchor.constraint(equalTo: screenView.centerYAnchor),

            menuButton.widthAnchor.constraint(equalToConstant: silkScreenButtonWidth),
            menuButton.heightAnchor.constraint(equalToConstant: silkScreenButtonWidth),
            menuButton.topAnchor.constraint(equalTo: program.rootView.topAnchor),
            menuButton.trailingAnchor.constraint(equalTo: program.rootView.leadingAnchor, constant: -silkScreenButtonHorizontalSpacing),

            clipboardButton.widthAnchor.constraint(equalToConstant: silkScreenButtonWidth),
            clipboardButton.heightAnchor.constraint(equalToConstant: silkScreenButtonWidth),
            clipboardButton.topAnchor.constraint(equalTo: menuButton.bottomAnchor, constant: silkScreenButtonVerticalSpacing),
            clipboardButton.trailingAnchor.constraint(equalTo: program.rootView.leadingAnchor, constant: -silkScreenButtonHorizontalSpacing),

            zoomInButton.widthAnchor.constraint(equalToConstant: silkScreenButtonWidth),
            zoomInButton.heightAnchor.constraint(equalToConstant: silkScreenButtonWidth),
            zoomInButton.topAnchor.constraint(equalTo: clipboardButton.bottomAnchor, constant: silkScreenButtonVerticalSpacing),
            zoomInButton.trailingAnchor.constraint(equalTo: program.rootView.leadingAnchor, constant: -silkScreenButtonHorizontalSpacing),

            zoomOutButton.widthAnchor.constraint(equalToConstant: silkScreenButtonWidth),
            zoomOutButton.heightAnchor.constraint(equalToConstant: silkScreenButtonWidth),
            zoomOutButton.topAnchor.constraint(equalTo: zoomInButton.bottomAnchor, constant: silkScreenButtonVerticalSpacing),
            zoomOutButton.trailingAnchor.constraint(equalTo: program.rootView.leadingAnchor, constant: -silkScreenButtonHorizontalSpacing),

            program.rootView.leadingAnchor.constraint(equalTo: screenView.leadingAnchor, constant: gutterWidth),
            program.rootView.trailingAnchor.constraint(equalTo: screenView.trailingAnchor, constant: -gutterWidth),
            program.rootView.topAnchor.constraint(equalTo: screenView.topAnchor),
            program.rootView.bottomAnchor.constraint(equalTo: screenView.bottomAnchor),

            screenView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            screenView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        navigationItem.rightBarButtonItems = [optionsBarButtonItem, keyboardBarButtonItem, controllerBarButtonItem]
        observeGameControllers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        screenView.transform = transformForInterfaceOrientation(UIApplication.shared.statusBarOrientation)
        settingsSink = settings.objectWillChange.sink { _ in }
        program.addObserver(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        program.resume()
        configureControllers()
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(titleBarTapped(sender:)))
        navigationController?.navigationBar.addGestureRecognizer(tapGestureRecognizer)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        virtualController?.disconnect()
        settingsSink?.cancel()
        settingsSink = nil
        program.suspend()
        program.removeObserver(self)
    }

    override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        UIView.animate(withDuration: duration) {
            self.screenView.transform = self.transformForInterfaceOrientation(toInterfaceOrientation)
        }
    }

    func transformForInterfaceOrientation(_ interfaceOrientation: UIInterfaceOrientation) -> CGAffineTransform {
        switch interfaceOrientation {
        case .portrait, .portraitUpsideDown:
            return CGAffineTransform(rotationAngle:  -.pi / 2)
        case .landscapeLeft, .landscapeRight:
            return CGAffineTransform(rotationAngle:  0)
        case .unknown:
            return CGAffineTransform(rotationAngle:  0)
        @unknown default:
            return CGAffineTransform(rotationAngle:  0)
        }
    }

    @objc func titleBarTapped(sender: UITapGestureRecognizer) {
        taskManager.showTaskList()
    }

    func observeGameControllers() {
        dispatchPrecondition(condition: .onQueue(.main))
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(forName: NSNotification.Name.GCControllerDidConnect,
                                       object: nil,
                                       queue: .main) { notification in
            self.configureControllers()
        }
    }

    func configureControllers() {
        for controller in GCController.controllers() {
            controller.extendedGamepad?.buttonHome?.pressedChangedHandler = self.pressedChangeHandler(for: .home)
            controller.extendedGamepad?.buttonA.pressedChangedHandler = self.pressedChangeHandler(for: .a)
            controller.extendedGamepad?.buttonB.pressedChangedHandler = self.pressedChangeHandler(for: .b)
            controller.extendedGamepad?.dpad.up.pressedChangedHandler = self.pressedChangeHandler(for: .up)
            controller.extendedGamepad?.dpad.down.pressedChangedHandler = self.pressedChangeHandler(for: .down)
            controller.extendedGamepad?.dpad.left.pressedChangedHandler = self.pressedChangeHandler(for: .left)
            controller.extendedGamepad?.dpad.right.pressedChangedHandler = self.pressedChangeHandler(for: .right)
            controller.extendedGamepad?.leftThumbstick.up.pressedChangedHandler = self.pressedChangeHandler(for: .up)
            controller.extendedGamepad?.leftThumbstick.down.pressedChangedHandler = self.pressedChangeHandler(for: .down)
            controller.extendedGamepad?.leftThumbstick.left.pressedChangedHandler = self.pressedChangeHandler(for: .left)
            controller.extendedGamepad?.leftThumbstick.right.pressedChangedHandler = self.pressedChangeHandler(for: .right)
            controller.extendedGamepad?.buttonOptions?.pressedChangedHandler = self.pressedChangeHandler(for: .options)
            controller.extendedGamepad?.buttonMenu.pressedChangedHandler = self.pressedChangeHandler(for: .menu)
        }
    }

    func updateControllerButton(_ controllerButton: ControllerButton, pressed: Bool) {
        guard controllerState[controllerButton] != pressed else {
            return
        }
        controllerState[controllerButton] = pressed
        guard let keyCode = controllerButtonMap[controllerButton] else {
            print("Controller button has no mapping (\(controllerButton)).")
            return
        }
        switch pressed {
        case true:
            program.sendKeyDown(keyCode)
            program.sendKeyPress(keyCode)
        case false:
            program.sendKeyUp(keyCode)
        }
    }

    func pressedChangeHandler(for controllerButton: ControllerButton) -> GCControllerButtonValueChangedHandler {
        return { button, value, pressed in
            self.updateControllerButton(controllerButton, pressed: pressed)
        }
    }

    @objc func controllerDidDisconnect(notification: NSNotification) {}

    @objc func keyboardTapped(sender: UIBarButtonItem) {
        program.toggleOnScreenKeyboard()
    }

    @objc func controllerButtonTapped(sender: UIBarButtonItem) {
        if let virtualController = virtualController {
            virtualController.disconnect()
            self.virtualController = nil
        } else {
            let configuration = GCVirtualController.Configuration()
            configuration.elements = [GCInputButtonA, GCInputButtonB, GCInputDirectionPad, GCInputDirectionPad, GCInputButtonHome, GCInputButtonOptions]
            virtualController = GCVirtualController(configuration: configuration)
            virtualController?.connect()
        }
    }

    func showConsole() {
        let viewController = ConsoleViewController(program: program)
        viewController.delegate = self
        let navigationController = UINavigationController(rootViewController: viewController)
        present(navigationController, animated: true)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key {
                let modifiers = key.oplModifiers()

                let (keydownCode, keypressCode) = key.toOplCodes()

                // The could be no legitimate keydownCode if we're inputting say
                // a tilde which is not on a key that the Psion 5 keyboard has
                if let code = keydownCode {
                    program.sendEvent(.keydownevent(.init(timestamp: press.timestamp, keycode: code, modifiers: modifiers)))
                } else {
                    print("No keydown code for \(key)")
                }

                if let code = keypressCode, code.toCharcode() != nil {
                    let event = Async.KeyPressEvent(timestamp: press.timestamp, keycode: code, modifiers: modifiers, isRepeat: false)
                    if event.modifiedKeycode() != nil {
                        program.sendEvent(.keypressevent(event))
                    }
                } else {
                    print("No keypress code for \(key)")
                }
            }
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key {
                let (oplKey, _) = key.toOplCodes()
                if let oplKey = oplKey {
                    let modifiers = key.oplModifiers()
                    program.sendEvent(.keyupevent(.init(timestamp: press.timestamp, keycode: oplKey, modifiers: modifiers)))
                }
            }
        }
    }

}

extension ProgramViewController: ConsoleViewControllerDelegate {

    func consoleViewControllerDidDismiss(_ consoleViewController: ConsoleViewController) {
        dispatchPrecondition(condition: .onQueue(.main))
        let shouldPopViewController = program.state == .finished
        consoleViewController.dismiss(animated: true) {
            guard shouldPopViewController else {
                return
            }
            self.navigationController?.popViewController(animated: true)
        }
    }

}

extension ProgramViewController: DrawableViewControllerDelegate {

    func drawableViewControllerDidFinish(_ drawableViewController: DrawableViewController) {
        dispatchPrecondition(condition: .onQueue(.main))
        drawableViewController.dismiss(animated: true)
    }

}

extension ProgramViewController: ProgramDelegate {

    func programDidRequestBackground(_ program: Program) {
        _ = DispatchQueue.main.sync {
            self.navigationController?.popViewController(animated: true)
        }
    }

    func programDidRequestTaskList(_ program: Program) {
        DispatchQueue.main.async {
            self.taskManager.showTaskList()
        }
    }

    func readLine(escapeShouldErrorEmptyInput: Bool) -> String? {
        // TODO: Implement INPUT
        return "123"
    }

    func program(_ program: Program, showAlertWithLines lines: [String], buttons: [String]) -> Int {
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

    func dialog(_ dialog: Dialog) -> Dialog.Result {
        let semaphore = DispatchSemaphore(value: 0)
        var result = Dialog.Result(result: 0, values: [])
        DispatchQueue.main.async {
            result = Dialog.Result(result: 0, values: [])
            let viewController = DialogViewController(dialog: dialog) { key, values in
                result = Dialog.Result(result: key, values: values)
                semaphore.signal()
            }
            let navigationController = UINavigationController(rootViewController: viewController)
            self.present(navigationController, animated: true)
        }
        semaphore.wait()
        return result
    }
}

extension ProgramViewController: ProgramLifecycleObserver {

    func program(_ program: Program, didFinishWithResult result: OpoInterpreter.Result) {
        if case OpoInterpreter.Result.none = result {
            self.navigationController?.popViewController(animated: true)
            return
        }
        UIView.animate(withDuration: 0.3) {
            self.program.rootView.alpha = 0.3
        } completion: { _ in
            self.showConsole()
        }
    }

    func program(_ program: Program, didEncounterError error: Error) {
        present(error: error)
    }

    func program(_ program: Program, didUpdateTitle title: String) {
        self.title = title
    }

}
