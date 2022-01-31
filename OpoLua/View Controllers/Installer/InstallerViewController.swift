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

import SwiftUI
import UIKit

protocol InstallerViewControllerDelegate: AnyObject {

    func installerViewControllerDidFinish(_ installerViewController: InstallerViewController)

}

class InstallerViewController: UINavigationController {

    private let settings: Settings
    var url: URL
    var installer: Installer?

    weak var installerDelegate: InstallerViewControllerDelegate?

    init(settings: Settings, url: URL, preferredDestinationUrl: URL? = nil) {
        self.settings = settings
        self.url = url
        let introductionViewController = InstallerIntroductionViewController(settings: settings,
                                                                             url: url,
                                                                             preferredDestinationUrl: preferredDestinationUrl)
        super.init(rootViewController: introductionViewController)
        isModalInPresentation = true
        introductionViewController.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showSummary(state: InstallerSummaryViewController.State) {
        let viewController = InstallerSummaryViewController(state: state)
        viewController.delegate = self
        pushViewController(viewController, animated: true)
    }

}

extension InstallerViewController: InstallerIntroductionViewControllerDelegate {

    func installerIntroductionViewControllerDidCancel(_ installerIntroductionViewController: InstallerIntroductionViewController) {
        self.installerDelegate?.installerViewControllerDidFinish(self)
    }

    func installerIntroductionViewController(_ installerIntroductionViewController: InstallerIntroductionViewController,
                                             continueWithDestinationUrl destinationUrl: URL) {
        dispatchPrecondition(condition: .onQueue(.main))

        let systemUrl = destinationUrl.appendingPathComponent(url.basename.deletingPathExtension)
        guard !FileManager.default.fileExists(atUrl: systemUrl) else {
            // Since we don't provide a mechanism to explicitly pick existing systems, we explicitly fail if a system
            // already exists with the auto-generated name. In the future, when we have a better picker, we can relax
            // this constraint.
            self.showSummary(state: .failure(OpoLuaError.fileExists))
            return
        }

        let installer = Installer(url: url, fileSystem: SystemFileSystem(rootUrl: systemUrl))
        self.installer = installer
        installer.delegate = self
        installer.run()
    }

    func installerIntroductionViewControllerDidContinue(_ installerIntroductionViewController: InstallerIntroductionViewController) {

    }

}

extension InstallerViewController: InstallerDelegate {

    func installerDidComplete(_ installer: Installer) {
        DispatchQueue.main.async {
            self.showSummary(state: .success)
        }
    }

    func installer(_ installer: Installer, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.showSummary(state: .failure(error))
        }
    }

}

extension InstallerViewController: InstallerSummaryViewControllerDelegate {

    func installerSummaryViewControllerDidFinish(_ installerSummaryViewController: InstallerSummaryViewController) {
        installerDelegate?.installerViewControllerDidFinish(self)
    }

}
