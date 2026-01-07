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

    var window: UIWindow?

    private let settings: Settings
    private let taskManager: TaskManager
    private let detector: ProgramDetector
    let downloader: UbiquitousDownloader

    private var rootViewController: RootViewController!
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

        rootViewController = RootViewController(settings: settings, taskManager: taskManager, detector: detector)

        window = UIWindow()
        window?.rootViewController = rootViewController
        window?.tintColor = settings.theme.color
        window?.makeKeyAndVisible()

        settingsSink = settings.objectWillChange.sink { _ in
            self.window?.tintColor = self.settings.theme.color
        }

        taskManager.delegate = self

        detector.start()
        downloader.start()

        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        guard url.startAccessingSecurityScopedResource() else {
            rootViewController.present(error: OpoLuaError.secureAccess)
            return false
        }
        install(url: url)
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
        rootViewController.showAbout()
    }

    @objc func showSettings() {
        rootViewController.showSettings()
    }

    func install(url: URL, preferredDestinationUrl: URL? = nil, sourceUrl: URL? = nil) {
        let installerViewController = InstallerViewController(settings: settings,
                                                              url: url,
                                                              preferredDestinationUrl: preferredDestinationUrl,
                                                              sourceUrl: sourceUrl)
        installerViewController.installerDelegate = self
        rootViewController.present(installerViewController, animated: true)
    }

    func runApplication(_ applicationIdentifier: ApplicationIdentifier, url: URL) -> Int32 {
        dispatchPrecondition(condition: .onQueue(.main))
        switch applicationIdentifier {
        case .textEditor:
            let viewController = SourceViewController(url: url, showsDoneButton: true)
            viewController.delegate = self
            let navigationController = UINavigationController(rootViewController: viewController)
            rootViewController.present(navigationController, animated: true)
            return 1
        }
    }

    func showUrl(_ url: URL) {
        rootViewController.showUrl(url)
    }
    
}

extension AppDelegate: SourceViewControllerDelelgate {

    func sourceViewControllerDidFinish(_ sourceViewController: SourceViewController) {
        sourceViewController.dismiss(animated: true)
    }

}

extension AppDelegate: InstallerViewControllerDelegate {

    func installerViewControllerDidFinish(_ installerViewController: InstallerViewController) {
        dispatchPrecondition(condition: .onQueue(.main))
        installerViewController.dismiss(animated: true)
    }

    func installerViewController(_ installerViewController: InstallerViewController,
                                 didInstallToDestinationUrl destinationUrl: URL) {
        dispatchPrecondition(condition: .onQueue(.main))
        installerViewController.dismiss(animated: true)
        rootViewController.showUrl(destinationUrl)
    }

}

extension AppDelegate: TaskManagerDelegate {

    func taskManagerShowTaskList(_ taskManager: TaskManager) {
        let taskManagerViewController = TaskManagerViewController(settings: settings, taskManager: taskManager)
        let navigationController = UINavigationController(rootViewController: taskManagerViewController)
        rootViewController.present(navigationController, animated: true)
    }

    func taskManager(_ taskManager: TaskManager, bringProgramToForeground program: Program) {
        rootViewController.bringProgramToForeground(program)
    }

}

