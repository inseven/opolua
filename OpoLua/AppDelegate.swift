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

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    var window: UIWindow?
    var section: ApplicationSection?
    var previousSection: ApplicationSection = .allPrograms  // Represents the previously active section; always the one we expand to when entering split view.
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
        splitViewController.preferredDisplayMode = .automatic
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

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        guard url.startAccessingSecurityScopedResource() else {
            splitViewController.present(error: OpoLuaError.secureAccess)
            return false
        }
        install(url: url)
        return true
    }

    func install(url: URL, preferredDestinationUrl: URL? = nil) {
        let installerViewController = InstallerViewController(settings: settings,
                                                              url: url,
                                                              preferredDestinationUrl: preferredDestinationUrl)
        installerViewController.installerDelegate = self
        splitViewController.present(installerViewController, animated: true)
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
        let directory = Directory(url: url)
        let viewController = DirectoryViewController(settings: settings, taskManager: taskManager, directory: directory)
        setRootDetailViewController(viewController, animated: animated)
    }

    func showSection(_ section: ApplicationSection, animated: Bool = true) {
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
        case .external(let url):
            showDirectory(url: url, animated: animated)
        }
    }

    private var activeViewController: UIViewController {
        return detailNavigationController.viewControllers.last!
    }

    private var detailNavigationController: UINavigationController {
        if splitViewController.isCollapsed {
            return splitViewController.viewControllers[0] as! UINavigationController
        } else {
            return splitViewController.viewControllers[1] as! UINavigationController
        }
    }

    func section(for url: URL) -> (ApplicationSection, [URL])? {
        guard let location = settings.indexableUrls.first(where: {
            url.path.starts(with: $0.path) || url.resolvingSymlinksInPath().path.starts(with: $0.path)
        }) else {
            return nil
        }
        let components = String(url.path.dropFirst(location.path.count)).split(separator: "/").map { String($0) }
        var directoryUrls: [URL] = []
        var loopUrl = location
        for component in components {
            loopUrl = loopUrl.appendingPathComponent(component)
            directoryUrls.append(loopUrl)
        }
        switch location {
        case Bundle.main.filesUrl, Bundle.main.scriptsUrl, Bundle.main.testsUrl:
            return (ApplicationSection.local(location), directoryUrls)
        case FileManager.default.documentsUrl:
            return (ApplicationSection.documents, [])
        default:
            return (ApplicationSection.external(location), directoryUrls)
        }
    }

    func showUrl(_ url: URL) {
        if let activeDirectoryViewController = activeViewController as? DirectoryViewController,
           activeDirectoryViewController.directory.url == url {
            print("Nothing to do!")
            return
        }
        guard let (section, urls) = section(for: url) else {
            print("Unable to determine section for '\(url)'.")
            return
        }
        self.showSection(section, animated: false)
        libraryViewController.selectSection(section: section)
        urls.map { DirectoryViewController(settings: settings,
                                           taskManager: taskManager,
                                           directory: Directory(url: $0)) }
        .forEach { detailNavigationController.pushViewController($0, animated: false) }
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
        showUrl(destinationUrl)
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
                               showSection section: ApplicationSection) {
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
