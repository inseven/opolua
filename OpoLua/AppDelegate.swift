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
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var taskManager = TaskManager()

    var settings = Settings()
    var splitViewController: UISplitViewController!
    var settingsSink: AnyCancellable?

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let libraryViewController = LibraryViewController(settings: settings, taskManager: taskManager)
        libraryViewController.delegate = self
        let navigationController = UINavigationController(rootViewController: libraryViewController)
        navigationController.navigationBar.prefersLargeTitles = true

        splitViewController = UISplitViewController(style: .doubleColumn)
        splitViewController.delegate = self
        splitViewController.preferredDisplayMode = .oneBesideSecondary
        splitViewController.preferredSplitBehavior = .tile
        splitViewController.setViewController(navigationController, for: .primary)

        window = UIWindow()
        window?.rootViewController = splitViewController
        window?.tintColor = settings.theme.color
        window?.makeKeyAndVisible()

        settingsSink = settings.objectWillChange.sink { _ in
            self.window?.tintColor = self.settings.theme.color
        }

        return true
    }

    func setTheme(_ theme: Settings.Theme) {
        window?.tintColor = theme.color
    }
    
}

extension AppDelegate: UISplitViewControllerDelegate {

    func splitViewController(_ svc: UISplitViewController,
                             topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        print("splitViewcontroller(\(svc), topColumnForCollapsingToProposedColumn: \(proposedTopColumn.description))")
        return proposedTopColumn
    }

    func splitViewController(_ svc: UISplitViewController, willHide column: UISplitViewController.Column) {
        print("splitViewController(\(svc), willHide: \(column.description))")
    }

    func splitViewControllerDidCollapse(_ svc: UISplitViewController) {
        print("splitViewControllerDidCollapse(\(svc)")
        print(splitViewController.viewControllers)
    }

    func splitViewController(_ svc: UISplitViewController,
                             displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode) -> UISplitViewController.DisplayMode {
        print("splitViewController(\(svc), displayModeForExpandingToProposedDisplayMode: \(proposedDisplayMode.description))")
        return proposedDisplayMode
    }

    func splitViewController(_ svc: UISplitViewController, willShow column: UISplitViewController.Column) {
        print("splitViewController(\(svc), willShow: \(column.description))")
    }

    func splitViewControllerDidExpand(_ svc: UISplitViewController) {
        print("splitViewControllerDidExpand(\(svc))")
        guard let primaryNavigationController = splitViewController.viewControllers[0] as? UINavigationController else {
            return
        }
        if let viewControllers = primaryNavigationController.popToRootViewController(animated: false) {
            let navigationController = UINavigationController(rootViewController: viewControllers.first!)
            for viewController in viewControllers[1...] {
                navigationController.pushViewController(viewController, animated: false)
            }
            self.splitViewController.setViewController(navigationController, for: .secondary)
        }
    }

}

extension AppDelegate: LibraryViewControllerDelegate {

    func libraryViewController(_ libraryViewController: LibraryViewController, presentViewController viewController: UIViewController) {
        if splitViewController.isCollapsed {
            guard let navigationController = splitViewController.viewControllers[0] as? UINavigationController else {
                return
            }
            navigationController.pushViewController(viewController, animated: true)
        } else {
            // N.B. Somewhat counterintuitively we need to place our view controller in a navigation view controller
            // to ensure that it replaces the top level detail view controller, rather than always pushing onto it.
            let navigationController = UINavigationController(rootViewController: viewController)
            splitViewController.setViewController(navigationController, for: .secondary)
        }
    }
    
}
