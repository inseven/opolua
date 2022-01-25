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
    var section: LibraryViewController.ItemType?
    var previousSection: LibraryViewController.ItemType = .allPrograms  // Represents the previously active section; always the one we expand to when entering split view.
    // N.B. We only ever store previous section for state restoration as we always want to restore to at least the top-level of the section.

    private var settings = Settings()
    private lazy var taskManager: TaskManager = {
        return TaskManager(settings: settings)
    }()
    private lazy var detector: ProgramDetector = {
        return ProgramDetector(settings: settings)
    }()
    var splitViewController: UISplitViewController!
    var libraryViewController: LibraryViewController!
    var settingsSink: AnyCancellable?

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        libraryViewController = LibraryViewController(settings: settings, taskManager: taskManager, detector: detector)
        libraryViewController.delegate = self
        let navigationController = UINavigationController(rootViewController: libraryViewController)
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.delegate = self

        splitViewController = UISplitViewController(style: .doubleColumn)
        splitViewController.delegate = self
        splitViewController.preferredDisplayMode = .oneBesideSecondary
        splitViewController.preferredSplitBehavior = .tile
        splitViewController.setViewController(navigationController, for: .primary)
        showSection(.allPrograms)

        window = UIWindow()
        window?.rootViewController = splitViewController
        window?.tintColor = settings.theme.color
        window?.makeKeyAndVisible()

        settingsSink = settings.objectWillChange.sink { _ in
            self.window?.tintColor = self.settings.theme.color
        }

        taskManager.delegate = self

        detector.start()

        return true
    }

    func setDetailViewController(_ viewController: UIViewController) {
        if splitViewController.isCollapsed {
            guard let navigationController = splitViewController.viewControllers[0] as? UINavigationController else {
                return
            }
            navigationController.setViewControllers([navigationController.viewControllers[0], viewController], animated: true)
        } else {
            // N.B. Somewhat counterintuitively we need to place our view controller in a navigation view controller
            // to ensure that it replaces the top level detail view controller, rather than always pushing onto it.
            let navigationController = UINavigationController(rootViewController: viewController)
            splitViewController.setViewController(navigationController, for: .secondary)
        }
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

    func showSection(_ section: LibraryViewController.ItemType) {
        guard self.section != section else {
            if let detailNavigationController = splitViewController.viewControllers[1] as? UINavigationController {
                detailNavigationController.popToRootViewController(animated: true)
            }
            return
        }
        self.section = section

        switch section {
        case .runningPrograms:
            let viewController = RunningProgramsViewController(settings: settings, taskManager: taskManager)
            setDetailViewController(viewController)
        case .allPrograms:
            let viewController = AllProgramsViewController(settings: settings,
                                                           taskManager: taskManager,
                                                           detector: detector)
            setDetailViewController(viewController)
        case .local(let url):
            do {
                let directory = try Directory(url: url)
                let viewController = DirectoryViewController(settings: settings,
                                                             taskManager: taskManager,
                                                             directory: directory)
                setDetailViewController(viewController)
            } catch {
                splitViewController.present(error: error)
                // TODO: Clear selection?
            }
        case .external(let location):
            do {
                let directory = try Directory(url: location.url)
                let viewController = DirectoryViewController(settings: settings,
                                                             taskManager: taskManager,
                                                             directory: directory)
                setDetailViewController(viewController)
            } catch {
                splitViewController.present(error: error)
                // TODO: Clear selection?
            }
        }
    }

}

extension AppDelegate: LibraryViewControllerDelegate {

    // TODO: Return true or false for success or failure?
    func libraryViewController(_ libraryViewController: LibraryViewController,
                               showSection section: LibraryViewController.ItemType) {
        showSection(section)
    }

    func libraryViewController(_ libraryViewController: LibraryViewController,
                               presentViewController viewController: UIViewController) {
        setDetailViewController(viewController)
    }
    
}

extension AppDelegate: TaskManagerDelegate {

    func taskManagerShowTaskList(_ taskManager: TaskManager) {
        let taskManagerViewController = TaskManagerViewController(settings: settings, taskManager: taskManager)
        let navigationController = UINavigationController(rootViewController: taskManagerViewController)
        splitViewController.present(navigationController, animated: true)
    }

    func taskManager(_ taskManager: TaskManager, bringProgramToForeground program: Program) {
        let programViewController = ProgramViewController(settings: settings,
                                                          taskManager: taskManager,
                                                          program: program)
        setDetailViewController(programViewController)
    }

}

extension AppDelegate: UINavigationControllerDelegate {

    func navigationController(_ navigationController: UINavigationController,
                              willShow viewController: UIViewController,
                              animated: Bool) {
        // Detect navigation to the root view when collapsed as this indicates there's no section selected.
        // We also store the previously selected section to ensure we can return to this when expanding.
        guard splitViewController.isCollapsed, viewController == libraryViewController, let section = section else {
            return
        }
        previousSection = section
        self.section = nil
    }

}
