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
    var rootViewController: RootViewController!

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let appDelegate = AppDelegate.shared

        rootViewController = RootViewController(settings: appDelegate.settings,
                                                taskManager: appDelegate.taskManager,
                                                detector: appDelegate.detector)

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = rootViewController
        window?.tintColor = appDelegate.settings.theme.color
        window?.makeKeyAndVisible()

        appDelegate.sceneDelegate = self

        self.scene(scene, openURLContexts: connectionOptions.urlContexts)
    }

    func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
        for urlContext in urlContexts {
            let url = urlContext.url
            guard url.startAccessingSecurityScopedResource() else {
                rootViewController.present(error: OpoLuaError.secureAccess)
                continue
            }
            install(url: url)
        }
    }

    func install(url: URL, preferredDestinationUrl: URL? = nil, sourceUrl: URL? = nil) {
        let installerViewController = InstallerViewController(settings: AppDelegate.shared.settings,
                                                              url: url,
                                                              preferredDestinationUrl: preferredDestinationUrl,
                                                              sourceUrl: sourceUrl)
        installerViewController.installerDelegate = self
        rootViewController.present(installerViewController, animated: true)
    }

    func showUrl(_ url: URL) {
        rootViewController.showUrl(url)
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
