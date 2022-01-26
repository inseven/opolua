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

    var url: URL
    var installer: Installer

    weak var installerDelegate: InstallerViewControllerDelegate?

    init(url: URL) {
        self.url = url
        self.installer = Installer(url: url, fileSystem: SystemFileSystem(rootUrl: url.deletingPathExtension()))
        let introductionViewController = InstallerIntroductionViewController()
        super.init(rootViewController: introductionViewController)
        isModalInPresentation = true
        installer.delegate = self
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

    func installerIntroductionViewControllerDidContinue(_ installerIntroductionViewController: InstallerIntroductionViewController) {
        dispatchPrecondition(condition: .onQueue(.main))
        installer.run()
    }

}

extension InstallerViewController: InstallerDelegate {

    func installer(_ installer: Installer, didFinishWithResult result: OpoInterpreter.Result) {
        DispatchQueue.main.async {
            switch result {
            case .none:
                self.showSummary(state: .success)
            case .error(let error):
                self.showSummary(state: .failure(OpoLuaError.interpreterError(error)))
            }
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
