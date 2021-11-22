//
//  SwitchTableViewCell.swift
//  OpoLua
//
//  Created by Jason Barrie Morley on 22/11/2021.
//

import UIKit

class SwitchTableViewCell: UITableViewCell {

    lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    lazy var switchView: UISwitch = {
        let view = UISwitch()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(label)
        contentView.addSubview(switchView)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            switchView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            switchView.leadingAnchor.constraint(equalTo: label.trailingAnchor),
            switchView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
        ])

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
