//
//  PickerViewController.swift
//  OpoLua
//
//  Created by Jason Barrie Morley on 19/11/2021.
//

import UIKit

class PickerViewController : UITableViewController {
    
    var programs: [URL]
    
    init() {
        programs = Bundle.main.urls(forResourcesWithExtension: "opo", subdirectory: nil) ?? []
        super.init(style: .grouped)
        navigationItem.title = "Programs"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return programs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        let url = programs[indexPath.row]
        cell.textLabel?.text = FileManager.default.displayName(atPath: url.path)
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let viewController = ScreenViewController(url: programs[indexPath.row])
        navigationController?.pushViewController(viewController, animated: true)
    }
    
}
