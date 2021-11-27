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

class DialogViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var dialog: Dialog
    var completion: ((Int, [String]) -> Void)?
    var values: [String]

    var buttons: [Dialog.Button] {
        guard dialog.buttons.count > 0 else {
            return [Dialog.Button(key: 1, text: "Continue", flags: Set())]
        }
        return dialog.buttons
    }

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()

    lazy var buttonView: UIView = {
        let buttonView = UIView()
        buttonView.translatesAutoresizingMaskIntoConstraints = false

        var previousButton: UIButton? = nil
        let spacing = 8.0
        for button in buttons {
            let view = BorderedButton(style: .gray)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.tintColor = button.flags.contains(.isCancelButton) ? .systemRed : view.tintColor
            view.setTitle(button.text, for: .normal)
            view.addAction(UIAction(handler: { action in
                self.complete(key: button.key)
            }), for: .touchUpInside)
            buttonView.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: buttonView.layoutMarginsGuide.leadingAnchor, constant: 12.0),
                view.trailingAnchor.constraint(equalTo: buttonView.layoutMarginsGuide.trailingAnchor, constant: -12.0),
                view.heightAnchor.constraint(greaterThanOrEqualToConstant: 48.0)
            ])
            if let previousButton = previousButton {
                view.topAnchor.constraint(equalTo: previousButton.bottomAnchor, constant: spacing).isActive = true
            } else {
                view.topAnchor.constraint(equalTo: buttonView.layoutMarginsGuide.topAnchor).isActive = true
            }
            previousButton = view
        }
        if let previousButton = previousButton {
            previousButton.bottomAnchor.constraint(equalTo: buttonView.layoutMarginsGuide.bottomAnchor).isActive = true
        }
        return buttonView
    }()

    init(dialog: Dialog, completion: @escaping (Int, [String]) -> Void) {
        self.dialog = dialog
        self.completion = completion
        self.values = dialog.items.map { item in
            switch item.type {
            case .choice:
                // It's necessary to pre-populate the initially selected value from the choice.
                return "1"
            default:
                return item.value
            }
        }

        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = .systemGroupedBackground
        title = dialog.title

        view.addSubview(tableView)
        view.addSubview(buttonView)
        NSLayoutConstraint.activate([

            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: buttonView.topAnchor),

            buttonView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonView.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),

        ])

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidDisappear(_ animated: Bool) {
        if navigationController?.isBeingDismissed ?? false {
            completion?(0, self.values)
            completion = nil
        }
        super.viewDidDisappear(animated)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesBegan(presses, with: event)
        guard let key = presses.first?.key else {
            return
        }
        if key.keyCode == .keyboardReturnOrEnter {
            complete(key: 1)
        }
    }

    @objc func buttonTapped(sender: UIBarButtonItem) {
        complete(key: sender.tag)
    }

    func complete(key: Int) {
        guard let completion = completion else {
            return
        }
        self.completion = nil
        dismiss(animated: true) {
            completion(key, self.values)
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dialog.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = dialog.items[indexPath.row]
        switch item.type {
        case .text:
            let cell: UITableViewCell
            if !item.prompt.isEmpty && !item.value.isEmpty {
                cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            } else {
                cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            }
            cell.textLabel?.numberOfLines = 0
            if !item.prompt.isEmpty {
                cell.textLabel?.text = item.prompt
                cell.detailTextLabel?.text = item.value
            } else {
                cell.textLabel?.text = item.value
            }
            cell.selectionStyle = item.selectable ? .default : .none
            cell.accessoryType = .none
            if item.prompt.isEmpty, let alignment = item.alignment {
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = dialog.items[indexPath.row]
        switch item.type {
        case .text:
            guard item.selectable else {
                return
            }
            // TODO: Double check what should happen if there's a selectable item and user defined buttons!
            complete(key: indexPath.row + 2)
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
