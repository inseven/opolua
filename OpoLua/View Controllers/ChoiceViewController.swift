//
//  ChoiceViewController.swift
//  OpoLua
//
//  Created by Jason Barrie Morley on 22/11/2021.
//

import UIKit

class ChoiceViewController: UITableViewController {

    var choices: [String]
    var selection: Int {
        didSet {
            onChange(selection)
        }
    }
    var onChange: (Int) -> Void

    init(_ title: String, choices: [String], selection: Int, onChange: @escaping (Int) -> Void) {
        self.choices = choices
        self.onChange = onChange
        self.selection = selection
        super.init(style: .grouped)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return choices.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = choices[indexPath.row]
        cell.accessoryType = selection == indexPath.row ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if selection != indexPath.row {
            let selectedIndexPath = IndexPath(row: selection, section: 0)
            selection = indexPath.row
            tableView.reloadRows(at: [selectedIndexPath, indexPath], with: .fade)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

}
