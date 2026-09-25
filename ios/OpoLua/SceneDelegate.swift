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

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private var settings: Settings!
    private var taskManager: TaskManager!

    private var rootViewController: RootViewController!
    private var settingsSink: AnyCancellable?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let appDelegate = AppDelegate.shared
        settings = appDelegate.settings
        taskManager = appDelegate.taskManager

        rootViewController = RootViewController(settings: settings,
                                                taskManager: taskManager,
                                                detector: appDelegate.detector)

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = rootViewController
        window?.tintColor = settings.theme.color
        window?.makeKeyAndVisible()

        settingsSink = settings.objectWillChange.sink { _ in
            self.window?.tintColor = self.settings.theme.color
        }

        taskManager.delegate = self

        // Multiple scenes aren't supported, so the app delegate forwards its UI requests to this scene.
        appDelegate.sceneDelegate = self

        // URLs used to launch the app are delivered with the connection options rather than via `openURLContexts`.
        open(urlContexts: connectionOptions.urlContexts)
    }

    func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
        open(urlContexts: urlContexts)
    }

    private func open(urlContexts: Set<UIOpenURLContext>) {
        for urlContext in urlContexts {
            let url = urlContext.url
            guard url.startAccessingSecurityScopedResource() else {
                rootViewController.present(error: OpoLuaError.secureAccess)
                continue
            }
            install(url: url)
        }
    }

    func showAbout() {
        rootViewController.showAbout()
    }

    func showSettings() {
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

extension SceneDelegate: SourceViewControllerDelelgate {

    func sourceViewControllerDidFinish(_ sourceViewController: SourceViewController) {
        sourceViewController.dismiss(animated: true)
    }

}

extension SceneDelegate: InstallerViewControllerDelegate {

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

extension SceneDelegate: TaskManagerDelegate {

    func taskManagerShowTaskList(_ taskManager: TaskManager) {
        let taskManagerViewController = TaskManagerViewController(settings: settings, taskManager: taskManager)
        let navigationController = UINavigationController(rootViewController: taskManagerViewController)
        rootViewController.present(navigationController, animated: true)
    }

    func taskManager(_ taskManager: TaskManager, bringProgramToForeground program: Program) {
        rootViewController.bringProgramToForeground(program)
    }

}
