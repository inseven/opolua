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
    var section: LibraryViewController.ApplicationSection?
    var previousSection: LibraryViewController.ApplicationSection = .allPrograms  // Represents the previously active section; always the one we expand to when entering split view.
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

        // Ensure the documents directory exists.
        let fileManager = FileManager.default
        if !fileManager.directoryExists(atPath: fileManager.documentsUrl.path) {
            try! fileManager.createDirectory(at: fileManager.documentsUrl, withIntermediateDirectories: true)
        }

        libraryViewController = LibraryViewController(settings: settings, taskManager: taskManager, detector: detector)
        libraryViewController.delegate = self
        let navigationController = UINavigationController(rootViewController: libraryViewController)
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.delegate = self
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(titleBarTapped(sender:)))
        navigationController.navigationBar.addGestureRecognizer(tapGestureRecognizer)

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

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return false
    }

    @objc func titleBarTapped(sender: UITapGestureRecognizer) {
        taskManager.showTaskList()
    }

    func setRootDetailViewController(_ viewController: UIViewController, animated: Bool = true) {
        if splitViewController.isCollapsed {
            let navigationController = splitViewController.viewControllers[0] as! UINavigationController
            navigationController.setViewControllers([navigationController.viewControllers[0], viewController],
                                                    animated: animated)
        } else {
            let navigationController = UINavigationController(rootViewController: viewController)
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(titleBarTapped(sender:)))
            navigationController.navigationBar.addGestureRecognizer(tapGestureRecognizer)
            splitViewController.setViewController(navigationController, for: .secondary)
        }
    }

    func showDirectory(url: URL, animated: Bool) {
        do {
            let directory = try Directory(url: url)
            let viewController = DirectoryViewController(settings: settings, taskManager: taskManager, directory: directory)
            setRootDetailViewController(viewController, animated: animated)
        } catch {
            splitViewController.present(error: error)
        }
    }

    func showSection(_ section: LibraryViewController.ApplicationSection, animated: Bool = true) {
        guard self.section != section else {
            if splitViewController.isCollapsed {
                if let navigationController = splitViewController.viewControllers[0] as? UINavigationController {
                    let viewController = navigationController.viewControllers[1]
                    navigationController.popToViewController(viewController, animated: animated)
                }
            } else {
                if splitViewController.viewControllers.count > 1,
                   let detailNavigationController = splitViewController.viewControllers[1] as? UINavigationController {
                    detailNavigationController.popToRootViewController(animated: animated)
                }
            }
            return
        }
        self.section = section

        switch section {
        case .runningPrograms:
            let viewController = RunningProgramsViewController(settings: settings, taskManager: taskManager)
            setRootDetailViewController(viewController)
        case .allPrograms:
            let viewController = AllProgramsViewController(settings: settings, taskManager: taskManager, detector: detector)
            setRootDetailViewController(viewController, animated: animated)
        case .documents:
            showDirectory(url: FileManager.default.documentsUrl, animated: animated)
        case .local(let url):
            showDirectory(url: url, animated: animated)
        case .external(let location):
            showDirectory(url: location.url, animated: animated)
        }
    }

    var activeViewController: UIViewController {
        if splitViewController.isCollapsed {
            let navigationController = splitViewController.viewControllers[0] as! UINavigationController
            return navigationController.viewControllers.last!
        } else {
            let navigationController = splitViewController.viewControllers[1] as! UINavigationController
            return navigationController.viewControllers.last!
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

}

extension AppDelegate: LibraryViewControllerDelegate {

    func libraryViewController(_ libraryViewController: LibraryViewController,
                               showSection section: LibraryViewController.ApplicationSection) {
        showSection(section)
    }
}

extension AppDelegate: TaskManagerDelegate {

    func taskManagerShowTaskList(_ taskManager: TaskManager) {
        let taskManagerViewController = TaskManagerViewController(settings: settings, taskManager: taskManager)
        let navigationController = UINavigationController(rootViewController: taskManagerViewController)
        splitViewController.present(navigationController, animated: true)
    }

    func taskManager(_ taskManager: TaskManager, bringProgramToForeground program: Program) {
        let activeViewController = self.activeViewController
        if let programViewController = activeViewController as? ProgramViewController,
           programViewController.program.url == program.url {
            return
        }
        let programViewController = ProgramViewController(settings: settings,
                                                          taskManager: taskManager,
                                                          program: program)
        section = .runningPrograms
        libraryViewController.selectSection(section: .runningPrograms)
        let runningProgramsViewController = RunningProgramsViewController(settings: settings, taskManager: taskManager)
        if splitViewController.isCollapsed {
            let navigationController = splitViewController.viewControllers[0] as! UINavigationController
            navigationController.setViewControllers([libraryViewController,
                                                     runningProgramsViewController,
                                                     programViewController],
                                                    animated: false)
        } else {
            let navigationController = splitViewController.viewControllers[1] as! UINavigationController
            navigationController.setViewControllers([runningProgramsViewController, programViewController],
                                                    animated: false)
        }
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
