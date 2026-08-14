import SwiftUI

struct SettingsView: View {
    @AppStorage("appearanceMode", store: SharedStorage.shared.defaults)
    private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("appTheme", store: SharedStorage.shared.defaults)
    private var appTheme = AppTheme.original.rawValue
    @AppStorage("askBeforeDownload", store: SharedStorage.shared.defaults)
    private var askBeforeDownload = true

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Settings")
                    .font(.largeTitle.bold())
                    .foregroundStyle(BrandPalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    Image("BrandIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("mDownloader")
                            .font(.title3.bold())
                            .foregroundStyle(BrandPalette.primaryText)
                        Text("Version \(version)")
                            .font(.subheadline)
                            .foregroundStyle(BrandPalette.secondaryText)
                    }
                    Spacer()
                }

                MockupSectionLabel(text: "Appearance")
                Picker("Appearance", selection: $appearanceMode) {
                    Text("Light").tag(AppearanceMode.light.rawValue)
                    Text("Dark").tag(AppearanceMode.dark.rawValue)
                    Text("System").tag(AppearanceMode.system.rawValue)
                }
                .pickerStyle(.segmented)

                MockupSectionLabel(text: "Theme")
                VStack(spacing: 0) {
                    themeRow(
                        theme: .basic,
                        title: "Basic",
                        subtitle: "Clean system look",
                        color: BrandPalette.elevated
                    )
                    Divider().overlay(BrandPalette.separator)
                    themeRow(
                        theme: .original,
                        title: "Original",
                        subtitle: "Themed with the logo",
                        color: BrandPalette.accent
                    )
                }
                .mDownloaderCard()

                MockupSectionLabel(text: "General")
                VStack(spacing: 0) {
                    settingRow(
                        icon: "folder.fill",
                        iconColor: .yellow,
                        title: "Download Folder",
                        trailing: "Downloads"
                    )
                    Divider().overlay(BrandPalette.separator)
                    HStack(spacing: 14) {
                        settingIcon("bell.fill", color: .yellow)
                        Text("Ask before download")
                            .font(.headline)
                            .foregroundStyle(BrandPalette.primaryText)
                        Spacer()
                        Toggle("Ask before download", isOn: $askBeforeDownload)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 78)
                }
                .mDownloaderCard()

                Text("Downloads use Apple’s background transfer service. Speed is not capped and automatically follows the server and your connection.")
                    .font(.footnote)
                    .foregroundStyle(BrandPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 30)
        }
    }

    private func themeRow(
        theme: AppTheme,
        title: String,
        subtitle: String,
        color: Color
    ) -> some View {
        Button {
            appTheme = theme.rawValue
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(BrandPalette.separator))
                    .frame(width: 48, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(BrandPalette.primaryText)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(BrandPalette.secondaryText)
                }
                Spacer()
                if appTheme == theme.rawValue {
                    Image(systemName: "checkmark")
                        .font(.headline.bold())
                        .foregroundStyle(BrandPalette.accent)
                }
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 78)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingRow(icon: String, iconColor: Color, title: String, trailing: String) -> some View {
        HStack(spacing: 14) {
            settingIcon(icon, color: iconColor)
            Text(title)
                .font(.headline)
                .foregroundStyle(BrandPalette.primaryText)
            Spacer()
            Text(trailing)
                .font(.subheadline)
                .foregroundStyle(BrandPalette.secondaryText)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(BrandPalette.secondaryText)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 78)
    }

    private func settingIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.title3)
            .foregroundStyle(color)
            .frame(width: 48, height: 48)
            .background(BrandPalette.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}

