// Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe
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
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    weak var sceneDelegate: SceneDelegate?

    let settings: Settings
    let taskManager: TaskManager
    let detector: ProgramDetector
    let downloader: UbiquitousDownloader

    private var settingsSink: AnyCancellable?

    override init() {
        settings = Settings()
        taskManager = TaskManager(settings: settings)
        detector = ProgramDetector(settings: settings)
        downloader = UbiquitousDownloader(settings: settings)
        super.init()
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Ensure the documents directory exists.
        let fileManager = FileManager.default
        if !fileManager.directoryExists(atPath: fileManager.documentsUrl.path) {
            try! fileManager.createDirectory(at: fileManager.documentsUrl, withIntermediateDirectories: true)
        }

        settingsSink = settings.objectWillChange.sink { [weak self] _ in
            guard let self else { return }
            sceneDelegate?.window?.tintColor = settings.theme.color
        }

        taskManager.delegate = self

        detector.start()
        downloader.start()

        return true
    }

    override func buildMenu(with builder: any UIMenuBuilder) {

        // This is apparently required to ensure we only modify the system menu.
        guard builder.system == UIMenuSystem.main else {
            return
        }

        let aboutCommand = UICommand(title: "About OpoLua", action: #selector(showAbout))
        let aboutMenu = UIMenu(title: "", options: .displayInline, children: [aboutCommand])
        builder.replace(menu: .about, with: aboutMenu)

        let settingsCommand = UIKeyCommand(title: "Settings...",
                                           action: #selector(showSettings),
                                           input: ",",
                                           modifierFlags: [.command])
        let settingsMenu = UIMenu(title: "", options: .displayInline, children: [settingsCommand])
        builder.replace(menu: .preferences, with: settingsMenu)
    }

    @objc func showAbout() {
        sceneDelegate?.rootViewController.showAbout()
    }

    @objc func showSettings() {
        sceneDelegate?.rootViewController.showSettings()
    }

    func install(url: URL, preferredDestinationUrl: URL? = nil, sourceUrl: URL? = nil) {
        sceneDelegate?.install(url: url, preferredDestinationUrl: preferredDestinationUrl, sourceUrl: sourceUrl)
    }

    func runApplication(_ applicationIdentifier: ApplicationIdentifier, url: URL) -> Int32 {
        dispatchPrecondition(condition: .onQueue(.main))
        switch applicationIdentifier {
        case .textEditor:
            let viewController = SourceViewController(url: url, showsDoneButton: true)
            viewController.delegate = self
            let navigationController = UINavigationController(rootViewController: viewController)
            sceneDelegate?.rootViewController.present(navigationController, animated: true)
            return 1
        }
    }

    func showUrl(_ url: URL) {
        sceneDelegate?.showUrl(url)
    }
    
}

extension AppDelegate: SourceViewControllerDelelgate {

    func sourceViewControllerDidFinish(_ sourceViewController: SourceViewController) {
        sourceViewController.dismiss(animated: true)
    }

}

extension AppDelegate: TaskManagerDelegate {

    func taskManagerShowTaskList(_ taskManager: TaskManager) {
        let taskManagerViewController = TaskManagerViewController(settings: settings, taskManager: taskManager)
        let navigationController = UINavigationController(rootViewController: taskManagerViewController)
        sceneDelegate?.rootViewController.present(navigationController, animated: true)
    }

    func taskManager(_ taskManager: TaskManager, bringProgramToForeground program: Program) {
        sceneDelegate?.rootViewController.bringProgramToForeground(program)
    }

}
