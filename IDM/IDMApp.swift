import SwiftUI
import UIKit
import AppIntents

final class AppDelegate: NSObject, UIApplicationDelegate {
    var backgroundSessionCompletionHandler: (() -> Void)?

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        backgroundSessionCompletionHandler = completionHandler
        DownloadManager.shared.reconnectBackgroundSessionIfNeeded(identifier: identifier)
    }
}

@main
struct IDMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var downloads = DownloadManager.shared
    @StateObject private var library = FileLibrary()
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appTheme") private var appTheme = "System"

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootView()
                } else {
                    OnboardingView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            hasCompletedOnboarding = true
                        }
                    }
                }
            }
            .environmentObject(downloads)
            .environmentObject(library)
            .environmentObject(themeManager)
            .preferredColorScheme(colorScheme)
            .task { importPendingSharedDownloads() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { importPendingSharedDownloads() }
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "Dark": .dark
        case "System": nil
        default: .light
        }
    }

    private func importPendingSharedDownloads() {
        for url in SharedDownloadInbox.takeAll() {
            downloads.addDownload(url: url)
        }
    }
}

// MARK: - Shortcuts / share integration

/// App Group inbox shared with the Share extension. The extension writes the
/// link before attempting to open the app, so iOS cannot silently lose a share.
enum SharedDownloadInbox {
    static let appGroupIdentifier = "group.com.munesh.IDM"
    static let pendingLinksKey = "mDownloader.pendingSharedLinks"

    private static var defaults: UserDefaults? {
        guard FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) != nil else { return nil }
        return UserDefaults(suiteName: appGroupIdentifier)
    }

    static func take(id: String) -> URL? {
        guard let defaults else { return nil }
        var entries = pendingEntries(from: defaults)
        guard let index = entries.firstIndex(where: { $0["id"] == id }),
              let value = entries[index]["url"],
              let url = validatedHTTPURL(value) else { return nil }
        entries.remove(at: index)
        defaults.set(entries, forKey: pendingLinksKey)
        defaults.synchronize()
        return url
    }

    static func takeAll() -> [URL] {
        guard let defaults else { return [] }
        let urls = pendingEntries(from: defaults).compactMap { entry in
            entry["url"].flatMap(validatedHTTPURL)
        }
        defaults.removeObject(forKey: pendingLinksKey)
        defaults.synchronize()
        return urls
    }

    private static func pendingEntries(from defaults: UserDefaults) -> [[String: String]] {
        defaults.array(forKey: pendingLinksKey) as? [[String: String]] ?? []
    }

    private static func validatedHTTPURL(_ value: String) -> URL? {
        guard let url = URL(string: value),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }
}

/// "Download with mDownloader" exposed as an App Intent.
///
/// This is the reliable, sideload-proof way to hand a link to IDM: it works
/// from the Shortcuts app, the Action button, and Siri, and — once wrapped in a
/// Shortcut with "Show in Share Sheet" enabled — directly from the system share
/// menu, the same way Truecaller adds its own share action. Unlike a share
/// extension (which iOS often blocks from launching its host app), an App
/// Intent runs in-process and can open the app itself.
struct DownloadWithIDMIntent: AppIntent {
    static var title: LocalizedStringResource = "Download with mDownloader"
    static var description = IntentDescription("Send a link to mDownloader and start a background download.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Link")
    var link: String

    init() {}
    init(link: String) { self.link = link }

    @MainActor
    func perform() async throws -> some IntentResult {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = DownloadWithIDMIntent.firstHTTPURL(in: trimmed) {
            DownloadManager.shared.addDownload(url: url)
        }
        return .result()
    }

    private static func firstHTTPURL(in text: String) -> URL? {
        if let url = URL(string: text), let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return url
        }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        if let match = detector?.firstMatch(in: text, options: [], range: range),
           let url = match.url, let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return url
        }
        return nil
    }
}

struct IDMAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DownloadWithIDMIntent(),
            phrases: [
                "Download with \(.applicationName)",
                "Add a download to \(.applicationName)"
            ],
            shortTitle: "Download with mDownloader",
            systemImageName: "arrow.down.circle.fill"
        )
    }
}
