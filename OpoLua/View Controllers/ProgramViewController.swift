// Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe
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

    private var virtualController: GCVirtualController?
    private var settingsSink: AnyCancellable?
    private var keyRepeatTimer: Timer?

    lazy var controllerState: [ControllerButton: Bool] = {
        return ControllerButton.allCases.reduce(into: [ControllerButton: Bool]()) { partialResult, button in
            partialResult[button] = false
        }
    }()

    lazy var menuButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "filemenu.and.selection")
        let button = UIButton(configuration: configuration, primaryAction: UIAction() { [weak self] action in
            guard let self = self else {
                return
            }
            self.program.sendKey(.menu)
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        button.pointerStyleProvider = buttonProvider()
        return button
    }()

    lazy var clipboardButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "doc.on.clipboard")
        let button = UIButton(configuration: configuration, primaryAction: UIAction() { [weak self] action in
            guard let self = self else {
                return
            }
            self.program.sendKey(.clipboardSoftkey)
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        button.pointerStyleProvider = buttonProvider()
        return button
    }()

    lazy var zoomInButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "plus.magnifyingglass")
        let button = UIButton(configuration: configuration, primaryAction: UIAction() { [weak self] action in
            guard let self = self else {
                return
            }
            self.program.sendKey(.zoomInSoftkey)
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        button.pointerStyleProvider = buttonProvider()
        return button
    }()

    lazy var zoomOutButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "minus.magnifyingglass")
        let button = UIButton(configuration: configuration, primaryAction: UIAction() { [weak self] action in
            guard let self = self else {
                return
            }
            self.program.sendKey(.zoomOutSoftkey)
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        button.pointerStyleProvider = buttonProvider()
        return button
    }()

    lazy var optionsBarButtonItem: UIBarButtonItem = {
        var actions: [UIMenuElement] = []
        actions = actions + taskManager.actions(for: program.url)

        let shareScreenshotAction = UIAction(title: "Share Screenshot",
                                             image: UIImage(systemName: "square.and.arrow.up")) { [weak self] action in
            guard let self = self else {
                return
            }
            self.shareScreenshot()
        }
        let shareMenu = UIMenu(options: [.displayInline], children: [shareScreenshotAction])
        actions.append(shareMenu)

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

        let developerMenu = UIMenu(options: [.displayInline], children: [drawablesAction])
        actions.append(developerMenu)

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

    lazy var scaleView: AutoOrientView = {

        let screenView = UIView(frame: CGRect(origin: .zero, size: program.getDeviceInfo().0.cgSize()))
        screenView.translatesAutoresizingMaskIntoConstraints = false
        screenView.addSubview(program.rootView)
        screenView.addSubview(menuButton)
        screenView.addSubview(clipboardButton)
        screenView.addSubview(zoomInButton)
        screenView.addSubview(zoomOutButton)

        let silkScreenButtonWidth = 24.0
        let silkScreenButtonHorizontalSpacing = 8.0
        let silkScreenButtonVerticalSpacing = 16.0

        NSLayoutConstraint.activate([
            menuButton.widthAnchor.constraint(equalToConstant: silkScreenButtonWidth),
            menuButton.heightAnchor.constraint(equalToConstant: silkScreenButtonWidth),
            menuButton.leadingAnchor.constraint(equalTo: screenView.leadingAnchor),
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

            program.rootView.trailingAnchor.constraint(equalTo: screenView.trailingAnchor),
            program.rootView.topAnchor.constraint(equalTo: screenView.topAnchor),
            program.rootView.bottomAnchor.constraint(equalTo: screenView.bottomAnchor),
        ])

        let scaleView = AutoOrientView(contentView: screenView)
        scaleView.translatesAutoresizingMaskIntoConstraints = false
        scaleView.preservesSuperviewLayoutMargins = true

        return scaleView
    }()

    init(settings: Settings, taskManager: TaskManager, program: Program) {
        self.settings = settings
        self.taskManager = taskManager
        self.program = program
        super.init(nibName: nil, bundle: nil)
        program.delegate = self
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = UIColor(named: "ProgramBackground")

        title = program.title
        view.clipsToBounds = true

        view.addSubview(scaleView)
        NSLayoutConstraint.activate([
            scaleView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scaleView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scaleView.topAnchor.constraint(equalTo: view.topAnchor),
            scaleView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        if traitCollection.horizontalSizeClass == .compact {
            navigationItem.rightBarButtonItems = [optionsBarButtonItem]
            toolbarItems = [.flexibleSpace(), keyboardBarButtonItem, .fixedSpace(16.0), controllerBarButtonItem, .flexibleSpace()]
        } else {
#if targetEnvironment(macCatalyst)
            navigationItem.rightBarButtonItems = [optionsBarButtonItem]
#else
            navigationItem.rightBarButtonItems = [optionsBarButtonItem, keyboardBarButtonItem, controllerBarButtonItem]
#endif
            toolbarItems = []
        }

        observeGameControllers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settingsSink = settings.objectWillChange.sink { _ in }
        program.addObserver(self)
        navigationController?.setToolbarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        program.resume()
        configureControllers()
        becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        virtualController?.disconnect()
        settingsSink?.cancel()
        settingsSink = nil
        program.suspend()
        program.removeObserver(self)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        configureToolbar(animated: true)
    }

    func buttonProvider() -> UIButton.PointerStyleProvider {
        return { button, pointerEffect, pointerShape in
            return UIPointerStyle(effect: .automatic(UITargetedPreview(view: button)),
                                  shape: .roundedRect(button.frame.insetBy(dx: -8, dy: -8)))
        }
    }

    private func shareScreenshot() {
        let screenshot = self.program.screenshot()

        // We write the screenshot to a file to allow us to set a filename.
        let fileManager = FileManager.default
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd' at 'HH.mm.ss"
        let date = dateFormatter.string(from: Date())
        let basename = "\(program.title) Screenshot \(date)"

        guard let data = screenshot.pngData(),
              let filename = (basename as NSString).appendingPathExtension("png")
        else {
            let alert = UIAlertController(title: "Error",
                                          message: "Failed to create screenshot.",
                                          preferredStyle: .alert)
            alert.addAction(.init(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }

        let screenshotUrl = fileManager.temporaryDirectory.appendingPathComponent(filename)
        do {
            if fileManager.fileExists(atPath: screenshotUrl.path) {
                try fileManager.removeItem(at: screenshotUrl)
            }
            try data.write(to: screenshotUrl)
            let activityViewController = UIActivityViewController(activityItems: [screenshotUrl],
                                                                  applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = program.rootView
            self.present(activityViewController, animated: true)
        } catch {
            present(error: error)
        }
    }

    func observeGameControllers() {
        dispatchPrecondition(condition: .onQueue(.main))
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(forName: NSNotification.Name.GCControllerDidConnect,
                                       object: nil,
                                       queue: .main) { [weak self] notification in
            guard let self = self else {
                return
            }
            self.configureControllers()
        }
    }

    func configureToolbar(animated: Bool) {
        if traitCollection.horizontalSizeClass == .compact {
            navigationItem.setRightBarButtonItems([optionsBarButtonItem], animated: animated)
            setToolbarItems([.flexibleSpace(),
                             keyboardBarButtonItem,
                             .fixedSpace(16.0),
                             controllerBarButtonItem,
                             .flexibleSpace()],
                            animated: animated)
        } else {
#if targetEnvironment(macCatalyst)
            navigationItem.setRightBarButtonItems([optionsBarButtonItem], animated: animated)
#else
            navigationItem.setRightBarButtonItems([optionsBarButtonItem,
                                                   keyboardBarButtonItem,
                                                   controllerBarButtonItem],
                                                  animated: animated)
#endif
            setToolbarItems([], animated: animated)
        }
    }

    func configureControllers() {
        for controller in GCController.controllers() {
            let input = controller.physicalInputProfile

            for dpad in input.allDpads {
                dpad.left.pressedChangedHandler = self.pressedChangeHandler(for: .left)
                dpad.right.pressedChangedHandler = self.pressedChangeHandler(for: .right)
                dpad.up.pressedChangedHandler = self.pressedChangeHandler(for: .up)
                dpad.down.pressedChangedHandler = self.pressedChangeHandler(for: .down)
            }

            let buttons = input.buttons
            buttons[GCInputButtonHome]?.pressedChangedHandler = self.pressedChangeHandler(for: .home)
            buttons[GCInputButtonA]?.pressedChangedHandler = self.pressedChangeHandler(for: .a)
            buttons[GCInputButtonB]?.pressedChangedHandler = self.pressedChangeHandler(for: .b)
            buttons[GCInputButtonOptions]?.pressedChangedHandler = self.pressedChangeHandler(for: .options)
            buttons[GCInputButtonMenu]?.pressedChangedHandler = self.pressedChangeHandler(for: .menu)
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
        return { [weak self] button, value, pressed in
            guard let self = self else {
                return
            }
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
            configuration.elements = [GCInputButtonA,
                                      GCInputButtonB,
                                      GCInputDirectionPad]
            virtualController = GCVirtualController(configuration: configuration)
            virtualController?.connect()
        }
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key {
                let modifiers = key.oplModifiers()

                let (keydownCode, keypressCode) = key.toOplCodes()

                // There could be no legitimate keydownCode if we're inputting say
                // a tilde which is not on a key that the Psion 5 keyboard has
                if let code = keydownCode {
                    program.sendEvent(.keydownevent(.init(timestamp: press.timestamp,
                                                          keycode: code,
                                                          modifiers: modifiers)))
                } else {
                    print("No keydown code for \(key)")
                }

                if let code = keypressCode, code.toCharcode() != nil {
                    keyRepeatTimer?.invalidate()
                    let event = Async.KeyPressEvent(timestamp: press.timestamp,
                                                    keycode: code,
                                                    modifiers: modifiers,
                                                    isRepeat: false)
                    if event.modifiedKeycode() != nil {
                        program.sendEvent(.keypressevent(event))
                        func sendRepeat() {
                            let timestamp = ProcessInfo.processInfo.systemUptime
                            let event = Async.KeyPressEvent(timestamp: timestamp,
                                                            keycode: code,
                                                            modifiers: modifiers,
                                                            isRepeat: true)
                            program.sendEvent(.keypressevent(event))
                        }
                        let shouldRepeat = code != .menu // menu is extra special and doesn't repeat
                        if shouldRepeat {
                            keyRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false, block: { _ in
                                sendRepeat()
                                self.keyRepeatTimer?.invalidate()
                                self.keyRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true, block: { _ in
                                    sendRepeat()
                                })
                            })
                        }
                    }
                } else {
                    print("No keypress code for \(key)")
                }
            }
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        keyRepeatTimer?.invalidate()
        keyRepeatTimer = nil
        for press in presses {
            if let key = press.key {
                let (oplKey, _) = key.toOplCodes()
                if let oplKey = oplKey {
                    let modifiers = key.oplModifiers()
                    program.sendEvent(.keyupevent(.init(timestamp: press.timestamp,
                                                        keycode: oplKey,
                                                        modifiers: modifiers)))
                }
            }
        }
    }

}

extension ProgramViewController: ErrorViewControllerDelegate {

    func errorViewControllerDidFinish(_ errorViewController: ErrorViewController) {
        dispatchPrecondition(condition: .onQueue(.main))
        errorViewController.dismiss(animated: true)
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

    func program(_ program: Program, runApplication applicationIdentifier: ApplicationIdentifier, url: URL) -> Int32? {
        return DispatchQueue.main.sync {
            return AppDelegate.shared.runApplication(applicationIdentifier, url: url)
        }
    }

}

extension ProgramViewController: ProgramLifecycleObserver {

    func program(_ program: Program, didFinishWithResult result: Error?) {

        program.removeObserver(self)

        guard let error = result else {
            self.navigationController?.popViewController(animated: true)
            return
        }

        // Capture a screenshot before fading out the view.
        let screenshot = program.screenshot()

        // Disable and fade out the view to indicate that the program has terminated.
        UIView.animate(withDuration: 0.3) {
            self.program.rootView.alpha = 0.3
        }
        controllerBarButtonItem.isEnabled = false
        keyboardBarButtonItem.isEnabled = false
        optionsBarButtonItem.isEnabled = false
        menuButton.isEnabled = false
        clipboardButton.isEnabled = false
        zoomInButton.isEnabled = false
        zoomOutButton.isEnabled = false

        // Generate the GitHub issue URL and sharing activities.
        let gitHubIssueUrl = URL.gitHubIssueURL(for: error,
                                                title: program.title,
                                                sourceUrl: program.metadata.sourceUrl)
        let activities: [UIActivity] = if let gitHubIssueUrl {
            [RaiseGitHubIssueActivity(url: gitHubIssueUrl)]
        } else {
            []
        }

        let showErrorDetails: () -> Void = {
            let viewController = ErrorViewController(error: error, screenshot: screenshot, activities: activities)
            viewController.delegate = self
            let navigationController = UINavigationController(rootViewController: viewController)
            self.present(navigationController, animated: true)
        }

        if settings.alwaysShowErrorDetails {
            showErrorDetails()
            return
        }

        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel) { action in
            self.navigationController?.popViewController(animated: true)
        })
        alert.addAction(UIAlertAction(title: "Show Details", style: .default) { action in
            showErrorDetails()
        })
        if let gitHubIssueUrl {
            alert.addAction(UIAlertAction(title: "Raise GitHub Issue", style: .default) { action in
                UIApplication.shared.open(gitHubIssueUrl)
                self.navigationController?.popViewController(animated: true)
            })
        }
        present(alert, animated: true)
    }

    func program(_ program: Program, didUpdateTitle title: String) {
        self.title = title
    }

}
