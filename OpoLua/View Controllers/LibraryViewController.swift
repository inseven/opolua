// Copyright (c) 2021 Jason Morley, Tom Sutcliffe
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

class LibraryViewController : UITableViewController {
    
    let library = Library()
    
    init() {
        super.init(style: .grouped)
        title = "Programs"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = true
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return library.objects.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        let object = library.objects[indexPath.row]
        cell.textLabel?.text = object.name
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let viewController = ScreenViewController(object: library.objects[indexPath.row])
        navigationController?.pushViewController(viewController, animated: true)
    }

    override func tableView(_ tableView: UITableView,
                            contextMenuConfigurationForRowAt indexPath: IndexPath,
                            point: CGPoint) -> UIContextMenuConfiguration? {
        let object = library.objects[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            let runAction = UIAction(title: "Run", image: UIImage(systemName: "play")) { action in
                let viewController = ScreenViewController(object: object)
                self.navigationController?.pushViewController(viewController, animated: true)
            }
            let procedureActions = object.procedures.map { procedure in
                UIAction(title: procedure.name, image: UIImage(systemName: "function")) { action in
                    let viewController = ScreenViewController(object: object, procedureName: procedure.name)
                    self.navigationController?.pushViewController(viewController, animated: true)
                }
            }
            let procedureMenu = UIMenu(title: "", image: nil, identifier: nil, options: .displayInline, children: procedureActions)

            return UIMenu(title: "", children: [runAction, procedureMenu])
        }
    }
    
}
