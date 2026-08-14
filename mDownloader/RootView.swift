import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case downloads
    case files
    case settings

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .downloads: "arrow.down.to.line.compact"
        case .files: "folder.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct RootView: View {
    @State private var selectedTab: AppTab

    init() {
        let requested = ProcessInfo.processInfo.environment["MDOWNLOADER_TAB"]
        _selectedTab = State(initialValue: AppTab(rawValue: requested ?? "") ?? .downloads)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            BrandPalette.background.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .downloads:
                    DownloadsView()
                case .files:
                    FilesView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaPadding(.bottom, 86)

            AppTabBar(selection: $selectedTab)
        }
    }
}

private struct AppTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 21, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(selection == tab ? BrandPalette.accent : BrandPalette.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 19, style: .continuous)
                                .fill(BrandPalette.elevated)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(7)
        .background(.ultraThinMaterial)
        .overlay {
            Capsule().stroke(BrandPalette.separator, lineWidth: 1)
        }
        .clipShape(Capsule())
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
    }
}
