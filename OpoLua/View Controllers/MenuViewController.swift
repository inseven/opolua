//
//  MenuViewController.swift
//  OpoLua
//
//  Created by Jason Barrie Morley on 21/11/2021.
//

import UIKit

class MenuViewController: UITableViewController {
    
    let menu: Menu
    var completion: ((Menu.Item?) -> Void)?
    
    init(menu: Menu, completion: @escaping (Menu.Item?) -> Void) {
        self.menu = menu
        self.completion = completion
        super.init(style: .insetGrouped)
        title = menu.title
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
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menu.items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = menu.items[indexPath.row]
        let cell = UITableViewCell()
        cell.textLabel?.text = item.text
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = menu.items[indexPath.row]
        completion?(item)
        completion = nil
        self.dismiss(animated: true)
    }
    
}
