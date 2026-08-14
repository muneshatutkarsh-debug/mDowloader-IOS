import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var theme: ThemeManager
    @AppStorage("downloadFolderName") private var downloadFolderName = "Downloads"
    @AppStorage("simultaneousDownloads") private var simultaneousDownloads = 3
    @AppStorage("wifiOnly") private var wifiOnly = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("appTheme") private var appTheme = "System"
    @State private var cacheLabel = "Cache empty"
    @State private var showAbout = false

    private let folderOptions = ["Downloads", "Media", "Movies", "Music", "Documents"]

    /// Row surface that matches the active theme (themed card vs. system cell).
    private var rowBG: Color {
        theme.isOriginal ? Color.idmCard : Color(uiColor: .secondarySystemGroupedBackground)
    }

    var body: some View {
        Form {
            Section("General") {
                Picker(selection: $downloadFolderName) {
                    ForEach(folderOptions, id: \.self) { Text($0).tag($0) }
                } label: {
                    SettingsLabel(symbol: "folder.fill", color: .blue, title: "Download Location")
                }
                .pickerStyle(.navigationLink)
                .onChange(of: downloadFolderName) { _, _ in
                    NotificationCenter.default.post(name: .downloadLibraryDidChange, object: nil)
                }

                Picker(selection: $simultaneousDownloads) {
                    ForEach(1...6, id: \.self) { Text("\($0)").tag($0) }
                } label: {
                    SettingsLabel(symbol: "square.stack.3d.up.fill", color: .blue, title: "Simultaneous Downloads")
                }
                .pickerStyle(.menu)
                .tint(Color(uiColor: .secondaryLabel))
                .onChange(of: simultaneousDownloads) { _, _ in
                    downloads.applyTransferSettings()
                }

                Toggle(isOn: $wifiOnly) {
                    SettingsLabel(symbol: "wifi", color: .blue, title: "Download on Wi-Fi only")
                }
                .tint(.green)
            }
            .listRowBackground(rowBG)

            Section {
                ForEach(AppColorTheme.allCases) { option in
                    Button {
                        theme.theme = option
                    } label: {
                        HStack(spacing: 14) {
                            ThemeSwatch(theme: option)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .foregroundStyle(Color.idmInk)
                                Text(option.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(Color.idmSecondary)
                            }
                            Spacer()
                            if theme.theme == option {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.idmAccent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Theme")
            } footer: {
                Text("Basic keeps the clean system look. Original themes the whole app — including the Dynamic Island — with the mDownloader logo colors.")
            }
            .listRowBackground(rowBG)

            Section("Appearance") {
                Picker(selection: $appTheme) {
                    Text("System").tag("System")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                } label: {
                    SettingsLabel(symbol: "circle.lefthalf.filled", color: .gray, title: "Appearance")
                }
                .pickerStyle(.menu)
                .tint(Color(uiColor: .secondaryLabel))
            }
            .listRowBackground(rowBG)

            Section {
                SettingsLabel(symbol: "tray.and.arrow.down.fill", color: .blue, title: "Download with mDownloader")
            } header: {
                Text("Sharing")
            } footer: {
                Text("In Safari or any app, tap Share, then choose Download with mDownloader to send a link straight to your download queue. Progress shows on the Lock Screen and in the Dynamic Island.")
            }
            .listRowBackground(rowBG)

            Section("Other") {
                Toggle(isOn: $notificationsEnabled) {
                    SettingsLabel(symbol: "bell.badge.fill", color: .red, title: "Notifications")
                }
                .tint(.green)
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled { requestNotifications() }
                }

                Button {
                    let bytes = downloads.clearCache()
                    cacheLabel = bytes > 0
                        ? "Cleared " + ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                        : "Cache empty"
                } label: {
                    LabeledContent {
                        Text(cacheLabel).foregroundStyle(.secondary)
                    } label: {
                        SettingsLabel(symbol: "trash.fill", color: .gray, title: "Clear Cache")
                    }
                }
                .buttonStyle(.plain)

                Button {
                    showAbout = true
                } label: {
                    LabeledContent {
                        Text("Version 1.0.0").foregroundStyle(.secondary)
                    } label: {
                        SettingsLabel(symbol: "info.circle.fill", color: .gray, title: "About mDownloader")
                    }
                }
                .buttonStyle(.plain)
            }
            .listRowBackground(rowBG)
        }
        .scrollContentBackground(.hidden)
        .background(IDMBackground())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("mDownloader 1.0.0", isPresented: $showAbout) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A private, native download manager with background transfers and Live Activity progress.")
        }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if !granted { DispatchQueue.main.async { notificationsEnabled = false } }
        }
    }
}

private struct SettingsLabel: View {
    let symbol: String
    let color: Color
    let title: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color)
                .frame(width: 29, height: 29)
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                )
        }
    }
}

/// A small theme preview chip shown next to each theme row.
private struct ThemeSwatch: View {
    let theme: AppColorTheme

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(fill)
            .frame(width: 46, height: 30)
            .overlay(alignment: .leading) {
                if theme == .original {
                    Circle()
                        .fill(Color.idmArrowRed)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1))
                        .padding(.leading, 6)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
    }

    private var fill: AnyShapeStyle {
        switch theme {
        case .original:
            return AnyShapeStyle(LinearGradient(colors: [Color.idmGradTop, Color.idmGradBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .basic:
            return AnyShapeStyle(Color(uiColor: .systemBlue))
        }
    }
}
