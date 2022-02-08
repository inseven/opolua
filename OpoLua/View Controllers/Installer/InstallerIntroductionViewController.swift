// Copyright (c) 2021-2022 Jason Morley, Tom Sutcliffe
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

class IntroductionHeader: UICollectionReusableView {

    let imageView = UIImageView()
    let titleLabel = UILabel()
    let descriptionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {

        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.spacing = UIStackView.spacingUseSystem

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
        ])

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        stackView.addArrangedSubview(imageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        stackView.addArrangedSubview(titleLabel)

        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.font = .preferredFont(forTextStyle: .body)
        stackView.addArrangedSubview(descriptionLabel)
    }

}

protocol InstallerIntroductionViewControllerDelegate: AnyObject {

    func installerIntroductionViewController(_ installerIntroductionViewController: InstallerIntroductionViewController,
                                             continueWithDestinationUrl destinationUrl: URL)
    func installerIntroductionViewControllerDidCancel(_ installerIntroductionViewController: InstallerIntroductionViewController)

}

class InstallerIntroductionViewController: UICollectionViewController {

    enum Section {
        case header
        case body
    }

    enum Item: Hashable {
        case destination(URL)
    }

    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>

    private var dataSource: DataSource!

    private let settings: Settings
    private let preferredDestinationUrl: URL?
    weak var delegate: InstallerIntroductionViewControllerDelegate?

    private var destinationUrl: URL

    lazy var cancelBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(title: "Cancel",
                                            style: .plain,
                                            target: self,
                                            action: #selector(cancelTapped(sender:)))
        return barButtonItem
    }()

    lazy var continueButton: UIButton = {
        let buttonView = UIButton(configuration: .primaryWizardButton(title: "Next"),
                                  primaryAction: UIAction { [weak self] action in
            guard let self = self else {
                return
            }
            self.delegate?.installerIntroductionViewController(self, continueWithDestinationUrl: self.destinationUrl)
        })
        buttonView.translatesAutoresizingMaskIntoConstraints = false
        return buttonView
    }()

    lazy var footerView: UIStackView = {
        let footerView = WizardFooterView()
        footerView.translatesAutoresizingMaskIntoConstraints = false
        footerView.addArrangedSubview(continueButton)
        return footerView
    }()

    init(settings: Settings, preferredDestinationUrl: URL?) {
        self.settings = settings
        self.preferredDestinationUrl = preferredDestinationUrl
        self.destinationUrl = preferredDestinationUrl ?? FileManager.default.documentsUrl
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        super.init(collectionViewLayout: UICollectionViewCompositionalLayout.list(using: configuration))
        navigationItem.rightBarButtonItem = cancelBarButtonItem
        navigationItem.hidesBackButton = true

        view.addSubview(footerView)
        NSLayoutConstraint.activate([
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        collectionView.collectionViewLayout = createLayout()

        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, item in
            var configuration = cell.defaultContentConfiguration()
            switch item {
            case .destination(let url):
                configuration.text = "Destination"
                configuration.secondaryText = url.localizedName
                cell.contentConfiguration = configuration
                var backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
                backgroundConfiguration.backgroundColor = .secondarySystemBackground
                cell.backgroundConfiguration = backgroundConfiguration
            }
        }

        let headerRegistration = UICollectionView.SupplementaryRegistration<IntroductionHeader>(elementKind: UICollectionView.elementKindSectionHeader) {
            supplementaryView, string, indexPath in
            guard let section = self.dataSource.sectionIdentifier(for: indexPath.section) else {
                return
            }
            switch section {
            case .header:
                supplementaryView.imageView.image = Icon.installer().image(for: settings.theme)
                supplementaryView.titleLabel.text = "Install"
                supplementaryView.descriptionLabel.text = "Clicking 'Continue' will install the package into the selected destination.\n\nInstalled scripts and programs are sandboxed and cannot access files outisde of their own directory."
            case .body:
                supplementaryView.imageView.image = nil
                supplementaryView.titleLabel.text = nil
                supplementaryView.descriptionLabel.text = nil
            }
        }

        dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }

        dataSource.supplementaryViewProvider = { collectionView, elementKind, indexPath in
            if elementKind == UICollectionView.elementKindSectionHeader {
                return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
            }
            else {
                return nil
            }
        }

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update(animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: footerView.frame.size.height, right: 0)
    }

    private func createLayout() -> UICollectionViewLayout {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.backgroundColor = .systemBackground
        configuration.headerMode = .supplementary
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }

    private func update(animated: Bool) {
        var snapshot = Snapshot()
        snapshot.appendSections([.header, .body])
        snapshot.appendItems([.destination(destinationUrl)], toSection: .body)
        dataSource.apply(snapshot, animatingDifferences: animated)
    }

    @objc func cancelTapped(sender: UIBarButtonItem) {
        delegate?.installerIntroductionViewControllerDidCancel(self)
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        switch item {
        case .destination:
            var destinationUrls = [FileManager.default.documentsUrl]
            if let preferredDestinationUrl = preferredDestinationUrl {
                destinationUrls.append(preferredDestinationUrl)
            }
            let destinationPicker = DestinationPickerViewController(urls: destinationUrls, selectedUrl: destinationUrl)
            destinationPicker.delegate = self
            let navigationController = UINavigationController(rootViewController: destinationPicker)
            present(navigationController, animated: true)
        }
        collectionView.deselectItem(at: indexPath, animated: true)
    }

}

extension InstallerIntroductionViewController: DestinationPickerViewControllerDelegate {

    func destinationPickerViewControllerDidCancel(_ destinationPickerViewController: DestinationPickerViewController) {
        destinationPickerViewController.dismiss(animated: true)
    }

    func destinationPickerViewController(_ destinationPickerViewController: DestinationPickerViewController,
                                         didSelectUrl url: URL) {
        destinationUrl = url
        update(animated: true)
        destinationPickerViewController.dismiss(animated: true)
    }

}
