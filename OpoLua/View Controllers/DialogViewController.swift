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

class DialogViewController: UITableViewController {

    var dialog: Dialog
    var completion: (Int, [String]) -> Void
    var values: [String]

    lazy var barButtonItem: UIBarButtonItem = {
        // TODO: Work out what is default?
        let barButtonItem = UIBarButtonItem(title: "OK",
                                            style: .plain,
                                            target: self,
                                            action: #selector(buttonTapped(sender:)))
        barButtonItem.tag = dialog.buttons.first?.key ?? 0
        return barButtonItem
    }()

    init(dialog: Dialog, completion: @escaping (Int, [String]) -> Void) {
        print(dialog.items)
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
            if let alignment = item.alignment {
                switch alignment {
                case .left:
                    cell.textLabel?.textAlignment = .left
                case .right:
                    cell.textLabel?.textAlignment = .right
                case .center:
                    cell.textLabel?.textAlignment = .center
                }
            } else {
                cell.textLabel?.textAlignment = .natural
            }
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
            cell.tag = indexPath.row
            cell.label.text = item.prompt
            cell.switchView.addTarget(self, action: #selector(choiceValueDidChange(sender:)), for: .valueChanged)
            return cell
        case .edit:
            let cell = TextFieldTableViewCell()
            cell.tag = indexPath.row
            cell.textField.clearButtonMode = .whileEditing
            cell.textField.placeholder = item.prompt
            cell.textField.text = values[indexPath.row]
            cell.textField.addTarget(self, action: #selector(editValueDidChange(sender:)), for: .editingChanged)
            return cell
        case .xinput:
            let cell = TextFieldTableViewCell()
            cell.tag = indexPath.row
            cell.textField.isSecureTextEntry = true
            cell.textField.clearButtonMode = .whileEditing
            cell.textField.placeholder = item.prompt
            cell.textField.text = values[indexPath.row]
            cell.textField.addTarget(self, action: #selector(editValueDidChange(sender:)), for: .editingChanged)
            return cell
        case .long:
            let cell = UITableViewCell()
            cell.textLabel?.text = "\(item.type)"
            cell.selectionStyle = .none
            cell.accessoryType = .none
            cell.backgroundColor = .cyan
            return cell
        case .float:
            let cell = UITableViewCell()
            cell.textLabel?.text = "\(item.type)"
            cell.selectionStyle = .none
            cell.accessoryType = .none
            cell.backgroundColor = .magenta
            return cell
        case .time:
            let cell = UITableViewCell()
            cell.textLabel?.text = "\(item.type)"
            cell.selectionStyle = .none
            cell.accessoryType = .none
            cell.backgroundColor = .yellow
            return cell
        case .date:
            let cell = UITableViewCell()
            cell.textLabel?.text = "\(item.type)"
            cell.selectionStyle = .none
            cell.accessoryType = .none
            cell.backgroundColor = .red
            return cell
        case .separator:
            let cell = UITableViewCell()
            cell.textLabel?.text = "\(item.type)"
            cell.selectionStyle = .none
            cell.accessoryType = .none
            cell.backgroundColor = .green
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

    @objc func choiceValueDidChange(sender: UISwitch) {
        values[sender.tag] = String(sender.isOn ? String.true : String.false)
    }

    @objc func editValueDidChange(sender: UITextField) {
        values[sender.tag] = sender.text!
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
