// Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe
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
import SwiftUI

import Diligence

class RootViewController: UISplitViewController {

    private let settings: Settings
    private var taskManager: TaskManager
    private var detector: ProgramDetector
    private var libraryViewController: LibraryViewController

    private var section: ApplicationSection?
    private var previousSection: ApplicationSection = .allPrograms
    // Represents the previously active section; always the one we expand to when entering split view.
    // N.B. We only ever store previous section for state restoration as we always want to restore to at least the
    // top-level of the section.

    private var activeViewController: UIViewController {
        return detailNavigationController.viewControllers.last!
    }

    private var detailNavigationController: UINavigationController {
        if isCollapsed {
            return viewControllers[0] as! UINavigationController
        } else {
            return viewControllers[1] as! UINavigationController
        }
    }

    init(settings: Settings, taskManager: TaskManager, detector: ProgramDetector) {
        self.settings = settings
        self.taskManager = taskManager
        self.detector = detector
        self.libraryViewController = LibraryViewController(settings: settings,
                                                           taskManager: taskManager,
                                                           detector: detector)
        super.init(style: .doubleColumn)
        libraryViewController.delegate = self
        delegate = self
        preferredDisplayMode = .automatic
        primaryBackgroundStyle = .sidebar
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let navigationController = UINavigationController(rootViewController: libraryViewController)
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.delegate = self
        setViewController(navigationController, for: .primary)
        showSection(.allPrograms)
    }

    func setRootDetailViewController(_ viewController: UIViewController, animated: Bool = true) {
        if isCollapsed {
            let navigationController = viewControllers[0] as! UINavigationController
            navigationController.setViewControllers([navigationController.viewControllers[0], viewController],
                                                    animated: animated)
        } else {
            let navigationController = UINavigationController(rootViewController: viewController)
            setViewController(navigationController, for: .secondary)
        }
    }

    func showAbout() {
        let viewController = UIHostingController(rootView: AboutView(Legal.contents))
        self.present(viewController, animated: true)
    }

    func showSettings() {
        let viewController = UIHostingController(rootView: SettingsView(settings: settings))
        self.present(viewController, animated: true)
    }

    func showSection(_ section: ApplicationSection, animated: Bool = true) {
        guard self.section != section else {
            if isCollapsed {
                if let navigationController = viewControllers[0] as? UINavigationController {
                    let viewController = navigationController.viewControllers[1]
                    navigationController.popToViewController(viewController, animated: animated)
                }
            } else {
                if viewControllers.count > 1,
                   let detailNavigationController = viewControllers[1] as? UINavigationController {
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
            let viewController = AllProgramsViewController(settings: settings,
                                                           taskManager: taskManager,
                                                           detector: detector)
            setRootDetailViewController(viewController, animated: animated)
        case .documents:
            showDirectory(url: FileManager.default.documentsUrl, animated: animated)
        case .local(let url):
            showDirectory(url: url, animated: animated)
        case .external(let url):
            showDirectory(url: url, animated: animated)
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

    func bringProgramToForeground(_ program: Program) {
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
        if isCollapsed {
            let navigationController = viewControllers[0] as! UINavigationController
            navigationController.setViewControllers([libraryViewController,
                                                     runningProgramsViewController,
                                                     programViewController],
                                                    animated: false)
        } else {
            let navigationController = viewControllers[1] as! UINavigationController
            navigationController.setViewControllers([runningProgramsViewController, programViewController],
                                                    animated: false)
        }
    }

}

extension RootViewController: UISplitViewControllerDelegate {

    func splitViewController(_ svc: UISplitViewController,
                             topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        return proposedTopColumn
    }

    func splitViewController(_ svc: UISplitViewController, willHide column: UISplitViewController.Column) {
    }

    func splitViewControllerDidCollapse(_ svc: UISplitViewController) {
    }

    func splitViewController(_ svc: UISplitViewController,
                             displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode) -> UISplitViewController.DisplayMode {
        return proposedDisplayMode
    }

    func splitViewController(_ svc: UISplitViewController, willShow column: UISplitViewController.Column) {
    }

    func splitViewControllerDidExpand(_ svc: UISplitViewController) {
        guard let primaryNavigationController = viewControllers[0] as? UINavigationController else {
            return
        }
        if let viewControllers = primaryNavigationController.popToRootViewController(animated: false) {
            let navigationController = UINavigationController(rootViewController: viewControllers.first!)
            for viewController in viewControllers[1...] {
                navigationController.pushViewController(viewController, animated: false)
            }
            setViewController(navigationController, for: .secondary)
        }
        if let section = section {
            libraryViewController.selectSection(section: section)
        }
    }

    func showDirectory(url: URL, animated: Bool) {
        let directory = Directory(url: url)
        let viewController = DirectoryViewController(settings: settings, taskManager: taskManager, directory: directory)
        setRootDetailViewController(viewController, animated: animated)
    }

}

extension RootViewController: LibraryViewControllerDelegate {

    func libraryViewController(_ libraryViewController: LibraryViewController,
                               showSection section: ApplicationSection) {
        showSection(section)
    }
}

extension RootViewController: UINavigationControllerDelegate {

    func navigationController(_ navigationController: UINavigationController,
                              willShow viewController: UIViewController,
                              animated: Bool) {
        // Detect navigation to the root view when collapsed as this indicates there's no section selected.
        // We also store the previously selected section to ensure we can return to this when expanding.
        guard isCollapsed, viewController == libraryViewController,
              let section = section
        else {
            return
        }
        previousSection = section
        self.section = nil
    }

}
