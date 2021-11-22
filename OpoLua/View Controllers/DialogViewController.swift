//
//  DialogViewController.swift
//  OpoLua
//
//  Created by Jason Barrie Morley on 22/11/2021.
//

import UIKit

class DialogViewController: UITableViewController {

    var dialog: Dialog
    var completion: (Int, [String]) -> Void
    var values: [String]

    lazy var barButtonItem: UIBarButtonItem = {
        // TODO: Work out what is default?
        let barButtonItem = UIBarButtonItem(title: "OK", style: .plain, target: self, action: #selector(buttonTapped(sender:)))
        barButtonItem.tag = dialog.buttons.first?.key ?? 0
        return barButtonItem
    }()

    init(dialog: Dialog, completion: @escaping (Int, [String]) -> Void) {
        self.dialog = dialog
        self.completion = completion
        self.values = dialog.items.map { $0.value }
        super.init(style: .insetGrouped)
        title = dialog.title
        navigationItem.rightBarButtonItem = barButtonItem
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func buttonTapped(sender: UIBarButtonItem) {
        dismiss(animated: true) {
            self.completion(sender.tag, self.values)
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dialog.items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = dialog.items[indexPath.row]
        switch item.type {
        case .text:
            let cell = UITableViewCell()
            cell.textLabel?.text = item.value
            cell.selectionStyle = .none
            cell.accessoryType = .none
            return cell
        case .choice:
            let selection = selection(for: indexPath)
            let choices = item.choices ?? []
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = item.prompt
            cell.detailTextLabel?.text = selection >= 0 && selection < choices.count ? choices[selection] : ""
            cell.selectionStyle = .default
            cell.accessoryType = .disclosureIndicator
            return cell
        case .checkbox:
            let cell = SwitchTableViewCell()
            cell.label.text = item.prompt
            return cell
        default:
            let cell = UITableViewCell()
            cell.textLabel?.text = "\(item.type)"
            cell.selectionStyle = .none
            cell.accessoryType = .none
            return cell
        }
    }

    // TODO: Initial value before changing.
    func selection(for indexPath: IndexPath) -> Int {
        guard let selection = Int(values[indexPath.row]),
              selection > 0
        else {
            return 0
        }
        return selection - 1
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = dialog.items[indexPath.row]
        switch item.type {
        case .choice:
            let choices = item.choices ?? []
            let selection = selection(for: indexPath)
            let viewController = ChoiceViewController(item.prompt, choices: choices, selection: selection) { value in
                self.values[indexPath.row] = String(value + 1)
                tableView.reloadRows(at: [indexPath], with: .none)
            }
            navigationController?.pushViewController(viewController, animated: true)
        default:
            break
        }
    }

}
