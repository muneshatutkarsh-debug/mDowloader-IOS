import UIKit
import UniformTypeIdentifiers

/// Share-sheet target: "Download with mDownloader".
///
/// Appears in the system Share menu whenever a link is shared (from Safari and
/// most apps). It extracts the shared URL and hands it to the main IDM app via
/// the app's custom URL scheme (`idm://download?url=...`). The main app then
/// enqueues it on its background download session.
///
/// The link is first saved in an App Group inbox, then handed to the main app
/// with a deep link. If iOS refuses to open a Share extension's containing app,
/// the inbox is drained automatically the next time mDownloader becomes active.
final class ShareViewController: UIViewController {

    private var sharedURL: URL?
    private var actionCompleted = false

    private let card = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let urlLabel = UILabel()
    private let downloadButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    private let accent = UIColor.systemBlue

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildUI()
        extractSharedURL()
    }

    // MARK: - UI

    private func buildUI() {
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 24
        card.layer.cornerCurve = .continuous
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        iconView.image = UIImage(systemName: "arrow.down.circle.fill")
        iconView.tintColor = accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "Download with mDownloader"
        titleLabel.font = .systemFont(ofSize: 19, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        urlLabel.text = "Preparing link..."
        urlLabel.font = .systemFont(ofSize: 13, weight: .regular)
        urlLabel.textColor = .secondaryLabel
        urlLabel.textAlignment = .center
        urlLabel.numberOfLines = 3
        urlLabel.lineBreakMode = .byTruncatingMiddle
        urlLabel.translatesAutoresizingMaskIntoConstraints = false

        var dlConfig = UIButton.Configuration.filled()
        dlConfig.title = "Download"
        dlConfig.image = UIImage(systemName: "arrow.down.to.line")
        dlConfig.imagePadding = 8
        dlConfig.baseBackgroundColor = accent
        dlConfig.baseForegroundColor = .white
        dlConfig.cornerStyle = .large
        dlConfig.buttonSize = .large
        downloadButton.configuration = dlConfig
        downloadButton.addTarget(self, action: #selector(didTapDownload), for: .touchUpInside)
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        downloadButton.isEnabled = false

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.secondaryLabel, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconView)
        card.addSubview(titleLabel)
        card.addSubview(urlLabel)
        card.addSubview(downloadButton)
        card.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 360),

            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 26),
            iconView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 54),
            iconView.heightAnchor.constraint(equalToConstant: 54),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            urlLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            urlLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            downloadButton.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 22),
            downloadButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            downloadButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            cancelButton.topAnchor.constraint(equalTo: downloadButton.bottomAnchor, constant: 6),
            cancelButton.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])
    }

    // MARK: - Extraction

    private func extractSharedURL() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = item.attachments, !providers.isEmpty else {
            showInvalid()
            return
        }

        let urlType = UTType.url.identifier
        let textType = UTType.plainText.identifier

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] value, _ in
                let url = ShareViewController.url(from: value)
                DispatchQueue.main.async { self?.apply(url: url) }
            }
            return
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(textType) }) {
            provider.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] value, _ in
                let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let url = ShareViewController.firstURL(in: text)
                DispatchQueue.main.async { self?.apply(url: url) }
            }
            return
        }

        showInvalid()
    }

    private static func url(from value: Any?) -> URL? {
        if let url = value as? URL { return url }
        if let url = value as? NSURL { return url as URL }
        if let text = value as? String { return firstURL(in: text) }
        if let data = value as? Data,
           let text = String(data: data, encoding: .utf8) { return firstURL(in: text) }
        return nil
    }

    private static func firstURL(in text: String) -> URL? {
        if let url = URL(string: text), (url.scheme?.hasPrefix("http") ?? false) {
            return url
        }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        if let match = detector?.firstMatch(in: text, options: [], range: range),
           let url = match.url, (url.scheme?.hasPrefix("http") ?? false) {
            return url
        }
        return nil
    }

    private func apply(url: URL?) {
        guard let url, let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            showInvalid()
            return
        }
        sharedURL = url
        urlLabel.text = url.absoluteString
        downloadButton.isEnabled = true
    }

    private func showInvalid() {
        sharedURL = nil
        urlLabel.text = "No downloadable link was found in what you shared."
        downloadButton.isEnabled = false
    }

    // MARK: - Actions

    @objc private func didTapDownload() {
        if actionCompleted { complete(); return }
        guard let url = sharedURL else { complete(); return }
        let sharedID = enqueue(url)
        var components = URLComponents()
        components.scheme = "idm"
        components.host = "download"
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        if let sharedID {
            components.queryItems?.append(URLQueryItem(name: "shareID", value: sharedID))
        }
        if let deepLink = components.url {
            openHostApp(deepLink, isSafelyQueued: sharedID != nil)
        } else if sharedID != nil {
            showQueued()
        } else {
            showHandoffFailure()
        }
    }

    @objc private func didTapCancel() {
        complete()
    }

    /// Ask the extension host to open mDownloader. iOS may reject this for a
    /// Share extension, so the App Group queue remains the reliable fallback.
    private func openHostApp(_ url: URL, isSafelyQueued: Bool) {
        extensionContext?.open(url) { [weak self] opened in
            guard let self else { return }
            if opened {
                self.complete()
                return
            }

            if self.openUsingResponderChain(url) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    self?.complete()
                }
            } else if isSafelyQueued {
                self.showQueued()
            } else {
                self.showHandoffFailure()
            }
        }
    }

    private func openUsingResponderChain(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector) {
                _ = current.perform(selector, with: url)
                return true
            }
            responder = current.next
        }
        return false
    }

    private func enqueue(_ url: URL) -> String? {
        let groupID = "group.com.munesh.IDM"
        let key = "mDownloader.pendingSharedLinks"
        guard FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID
        ) != nil, let defaults = UserDefaults(suiteName: groupID) else { return nil }

        let id = UUID().uuidString
        var entries = defaults.array(forKey: key) as? [[String: String]] ?? []
        entries.append(["id": id, "url": url.absoluteString])
        defaults.set(entries, forKey: key)
        return defaults.synchronize() ? id : nil
    }

    private func showQueued() {
        actionCompleted = true
        iconView.image = UIImage(systemName: "checkmark.circle.fill")
        urlLabel.text = "Link saved. Open mDownloader and the download will start automatically."
        var config = downloadButton.configuration
        config?.title = "Done"
        config?.image = UIImage(systemName: "checkmark")
        downloadButton.configuration = config
        downloadButton.isEnabled = true
    }

    private func showHandoffFailure() {
        urlLabel.text = "Could not send this link. Open mDownloader once, then try sharing again."
        var config = downloadButton.configuration
        config?.title = "Try Again"
        config?.image = UIImage(systemName: "arrow.clockwise")
        downloadButton.configuration = config
        downloadButton.isEnabled = true
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
