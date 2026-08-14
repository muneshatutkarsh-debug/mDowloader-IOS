import SwiftUI

@main
struct mDownloaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var downloadManager = DownloadManager.shared
    @AppStorage("appearanceMode", store: SharedStorage.shared.defaults)
    private var appearanceMode = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(downloadManager)
                .preferredColorScheme(preferredColorScheme)
                .tint(BrandPalette.accent)
                .task {
                    if ProcessInfo.processInfo.environment["MDOWNLOADER_DEMO"] == "1",
                       let active = downloadManager.activeRecords.first {
                        LiveActivityController.shared.start(for: active)
                    }
                }
                .onOpenURL { url in
                    downloadManager.handleDeepLink(url)
                }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        if let demoAppearance = ProcessInfo.processInfo.environment["MDOWNLOADER_APPEARANCE"] {
            return demoAppearance == "dark" ? .dark : .light
        }
        switch AppearanceMode(rawValue: appearanceMode) ?? .system {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}
