//
//  MenuBarViewController.swift
//  OpoLua
//
//  Created by Jason Barrie Morley on 21/11/2021.
//

import UIKit

class MenuBarViewController: UITableViewController {
    
    let bar: Menu.Bar
    var completion: ((Menu.Item?) -> Void)?
    
    init(bar: Menu.Bar, completion: @escaping (Menu.Item?) -> Void) {
        self.bar = bar
        self.completion = completion
        super.init(style: .insetGrouped)
        title = "Menu"
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
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return bar.menus.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bar.menus[section].items.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return bar.menus[section].title
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = bar.menus[indexPath.section].items[indexPath.row]
        let cell = UITableViewCell()
        cell.textLabel?.text = item.text
        cell.accessoryType = item.submenu == nil ? .none : .disclosureIndicator
        cell.backgroundColor = item.flags.contains(.separatorAfter) ? .red : .systemBackground
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = bar.menus[indexPath.section].items[indexPath.row]
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
