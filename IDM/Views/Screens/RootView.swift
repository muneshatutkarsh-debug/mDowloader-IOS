import SwiftUI

/// The app's root navigation.
///
/// A pure download manager: Downloads, Files, and Settings, rendered with the
/// native iOS 26 `TabView` (the Liquid Glass dock). Downloads arrive either
/// from the in-app "Add Download" sheet or from the **Download with IDM** share
/// extension, which hands links to the app via `idm://download?url=...`.
struct RootView: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var selection: AppTab = .downloads

    var body: some View {
        TabView(selection: $selection) {
            Tab("Downloads", systemImage: "arrow.down.circle", value: AppTab.downloads) {
                NavigationStack { DownloadsView() }
            }
            Tab("Files", systemImage: "folder", value: AppTab.files) {
                NavigationStack { FilesView() }
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack { SettingsView() }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Color.idmAccent)
        .onOpenURL { url in handleIncomingURL(url) }
    }

    /// Handles `idm://` deep links:
    /// - `idm://download?url=<link>` from the share extension enqueues the link.
    /// - `idm://download/<id>` from a Live Activity tap just opens Downloads.
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "idm" else { return }
        selection = .downloads
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let target = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let downloadURL = URL(string: target),
              ["http", "https"].contains(downloadURL.scheme?.lowercased() ?? "") else { return }

        if let sharedID = components.queryItems?.first(where: { $0.name == "shareID" })?.value {
            if let queuedURL = SharedDownloadInbox.take(id: sharedID) {
                DownloadManager.shared.addDownload(url: queuedURL)
            }
            return
        }

        DownloadManager.shared.addDownload(url: downloadURL)
    }
}
