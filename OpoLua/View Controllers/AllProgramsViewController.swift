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

import UIKit

class AllProgramsViewController: UITableViewController {

    static let reuseIdentifier = "Cell"

    var settings: Settings
    var taskManager: TaskManager
    var detector: ProgramDetector
    var items: [Directory.Item] = []

    static let defaultLocations = [
        Bundle.main.filesUrl,
        Bundle.main.examplesUrl,
        Bundle.main.scriptsUrl,
    ]

    init(settings: Settings, taskManager: TaskManager) {
        self.settings = settings
        self.taskManager = taskManager
        self.detector = ProgramDetector(locations: Self.defaultLocations + settings.locations.map { $0.url })
        super.init(style: .plain)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.reuseIdentifier)
        navigationItem.largeTitleDisplayMode = .never
        title = "All Programs"
        self.detector.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        detector.update()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.reuseIdentifier, for: indexPath)
        let item = items[indexPath.row]
        cell.textLabel?.text = item.name
        cell.imageView?.image = item.icon().image(for: settings.theme)
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        let program = taskManager.program(for: item.programUrl!)
        let viewController = ProgramViewController(settings: settings, taskManager: taskManager, program: program)
        navigationController?.pushViewController(viewController, animated: true)
    }
}

extension AllProgramsViewController: ProgramDetectorDelegate {

    func programDetector(_ programDetector: ProgramDetector, didUpdateItems items: [Directory.Item]) {
        self.items = items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        tableView.reloadData()
    }

    func programDetector(_ programDetector: ProgramDetector, didFailWithError error: Error) {
        print("Failed to detect programs with error \(error).")
    }


}
