//
//  PickerViewController.swift
//  OpoLua
//
//  Created by Jason Barrie Morley on 19/11/2021.
//

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
    
}
