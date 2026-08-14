import UniformTypeIdentifiers
import UIKit

final class ShareViewController: UIViewController {
    private let storage = SharedStorage.shared
    private var sharedURL: URL?
    private var session: URLSession?

    private let iconView: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        let view = UIImageView(image: UIImage(systemName: "arrow.down", withConfiguration: configuration))
        view.tintColor = .white
        view.contentMode = .center
        view.backgroundColor = UIColor(red: 0.20, green: 0.34, blue: 0.66, alpha: 1)
        view.layer.cornerRadius = 18
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Download with mDownloader"
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private let linkLabel: UILabel = {
        let label = UILabel()
        label.text = "Reading shared link…"
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private lazy var downloadButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Download"
        configuration.image = UIImage(systemName: "arrow.down.circle.fill")
        configuration.imagePadding = 8
        configuration.cornerStyle = .large
        let button = UIButton(configuration: configuration)
        button.isEnabled = false
        button.addTarget(self, action: #selector(downloadTapped), for: .touchUpInside)
        return button
    }()

    private lazy var cancelButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Cancel"
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        preferredContentSize = CGSize(width: 0, height: 290)
        buildLayout()
        extractSharedURL()
    }

    private func buildLayout() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 58),
            iconView.heightAnchor.constraint(equalToConstant: 58)
        ])

        let labels = UIStackView(arrangedSubviews: [titleLabel, linkLabel])
        labels.axis = .vertical
        labels.spacing = 4

        let header = UIStackView(arrangedSubviews: [iconView, labels])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 14

        let buttons = UIStackView(arrangedSubviews: [cancelButton, downloadButton])
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 12

        let stack = UIStackView(arrangedSubviews: [header, buttons])
        stack.axis = .vertical
        stack.spacing = 28
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -6),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func extractSharedURL() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            showError("No link was shared.")
            return
        }

        let providers = items.flatMap { $0.attachments ?? [] }
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                let url = item as? URL ?? (item as? String).flatMap(URL.init(string:))
                DispatchQueue.main.async { self?.received(url) }
            }
            return
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                let text = (item as? String) ?? (item as? NSString).map(String.init)
                let url = text.flatMap(URL.init(string:))
                DispatchQueue.main.async { self?.received(url) }
            }
            return
        }

        showError("The shared item does not contain a downloadable link.")
    }

    private func received(_ url: URL?) {
        guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            showError("The shared item is not a valid HTTP or HTTPS link.")
            return
        }
        sharedURL = url
        linkLabel.text = url.absoluteString
        downloadButton.isEnabled = true

        if !storage.defaults.bool(forKey: "askBeforeDownload") && storage.defaults.object(forKey: "askBeforeDownload") != nil {
            startDownload(url)
        }
    }

    @objc private func downloadTapped() {
        guard let sharedURL else { return }
        startDownload(sharedURL)
    }

    @objc private func cancelTapped() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: "mDownloader.Share",
            code: NSUserCancelledError
        ))
    }

    private func startDownload(_ url: URL) {
        downloadButton.isEnabled = false
        let name = url.lastPathComponent.removingPercentEncoding.flatMap { $0.isEmpty ? nil : $0 }
            ?? "Download-\(Int(Date().timeIntervalSince1970))"
        var record = DownloadRecord(
            sourceURL: url.absoluteString,
            fileName: name,
            initiatedByShareExtension: true
        )
        record.state = .downloading
        storage.upsert(record)

        let configuration = URLSessionConfiguration.background(withIdentifier: AppGroup.shareBackgroundSession)
        configuration.sharedContainerIdentifier = AppGroup.identifier
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 8

        let session = URLSession(configuration: configuration)
        self.session = session
        var request = URLRequest(url: url)
        request.setValue("mDownloader/1.0", forHTTPHeaderField: "User-Agent")
        let task = session.downloadTask(with: request)
        task.taskDescription = record.id.uuidString
        task.resume()

        linkLabel.text = "Download started in the background."
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    private func showError(_ message: String) {
        linkLabel.text = message
        linkLabel.textColor = .systemRed
        downloadButton.isEnabled = false
    }
}

