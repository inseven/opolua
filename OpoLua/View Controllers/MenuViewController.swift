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

class MenuViewController: UITableViewController {

    struct MenuGroup {

        var title: String?
        var item: Menu.Item
    }
    
    let groups: [MenuGroup]
    var completion: ((Menu.Item?) -> Void)?

    lazy var closeBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark.circle.fill"),
                                            style: .plain,
                                            target: self,
                                            action: #selector(closeTapped(sender:)))
        barButtonItem.tintColor = .secondaryLabel
        return barButtonItem
    }()

    private init(title: String, groups: [MenuGroup], completion: @escaping (Menu.Item?) -> Void) {
        self.groups = groups
        self.completion = completion
        super.init(style: .insetGrouped)
        self.title = title
        navigationItem.rightBarButtonItem = closeBarButtonItem
        view.backgroundColor = .clear
    }
    
    convenience init(title: String, menu: Menu.Bar, completion: @escaping (Menu.Item?) -> Void) {
        var groups: [MenuGroup] = []
        for menu in menu.menus {
            var title: String? = menu.title
            for item in menu.items {
                groups.append(MenuGroup(title: title, item: item))
                title = nil
            }
        }
        self.init(title: title, groups: groups, completion: completion)
    }

    convenience init(menu: Menu, completion: @escaping (Menu.Item?) -> Void) {
        let groups = menu.items.map { MenuGroup(title: nil, item: $0) }
        self.init(title: menu.title, groups: groups, completion: completion)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if navigationController?.isBeingDismissed ?? false {
            completion?(nil)
            completion = nil
        }
        super.viewDidDisappear(animated)
    }

    @objc func closeTapped(sender: UIBarButtonItem) {
        self.dismiss(animated: true)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return groups.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return groups[section].title
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let item = groups[section].item
        return item.flags.contains(.separatorAfter) ? 16 : 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = groups[indexPath.section].item
        let cell = UITableViewCell()
        cell.textLabel?.text = item.text
        cell.accessoryType = item.submenu == nil ? .none : .disclosureIndicator
        cell.textLabel?.textColor = item.submenu == nil ? view.tintColor : UIColor.label
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = groups[indexPath.section].item
        if let submenu = item.submenu {
            let viewController = MenuViewController(menu: submenu, completion: completion!)
            navigationController?.pushViewController(viewController, animated: true)
        } else {
            print("Cheese")
            completion?(item)
            completion = nil
            self.dismiss(animated: true)
        }
    }
    
}
