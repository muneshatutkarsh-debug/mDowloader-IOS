import SwiftUI
import UIKit

struct DownloadsView: View {
    @EnvironmentObject private var manager: DownloadManager
    @State private var searchText = ""
    @State private var showingNewDownload = false

    private var visibleRecords: [DownloadRecord] {
        let matches = manager.records.filter { record in
            record.state != .cancelled && (
                searchText.isEmpty || record.fileName.localizedCaseInsensitiveContains(searchText)
            )
        }
        guard searchText.isEmpty else { return matches }

        let active = matches.filter { $0.state != .completed }
        let mostRecentCompleted = matches
            .filter { $0.state == .completed }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(1)
        return active + mostRecentCompleted
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(alignment: .center) {
                    Text("Downloads")
                        .font(.largeTitle.bold())
                        .foregroundStyle(BrandPalette.primaryText)
                    Spacer()
                    Button {
                        showingNewDownload = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.bold))
                            .frame(width: 40, height: 40)
                            .background(BrandPalette.elevated)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("New download")
                }

                MockupSearchField(placeholder: "Search downloads", text: $searchText)
                MockupSectionLabel(text: "Active & Recent")

                if visibleRecords.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(visibleRecords.enumerated()), id: \.element.id) { index, record in
                            DownloadRow(record: record)
                            if index < visibleRecords.count - 1 {
                                Divider().overlay(BrandPalette.separator)
                            }
                        }
                    }
                    .mDownloaderCard()
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 30)
        }
        .refreshable { manager.refreshFromDisk() }
        .sheet(isPresented: $showingNewDownload) {
            DownloadInputSheet()
                .environmentObject(manager)
                .presentationDetents([.medium, .large])
        }
        .alert("Couldnâ€™t start download", isPresented: errorBinding) {
            Button("OK", role: .cancel) { manager.lastErrorMessage = nil }
        } message: {
            Text(manager.lastErrorMessage ?? "The link could not be downloaded.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 48))
                .symbolRenderingMode(.palette)
                .foregroundStyle(BrandPalette.lightAccent, BrandPalette.elevated)
            Text("Ready for your first download")
                .font(.headline)
                .foregroundStyle(BrandPalette.primaryText)
            Text("Share a link from any browser, or paste a direct file link here.")
                .font(.subheadline)
                .foregroundStyle(BrandPalette.secondaryText)
                .multilineTextAlignment(.center)
            Button("Paste Link", systemImage: "doc.on.clipboard") {
                showingNewDownload = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .padding(.horizontal, 24)
        .mDownloaderCard()
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { manager.lastErrorMessage != nil },
            set: { if !$0 { manager.lastErrorMessage = nil } }
        )
    }
}

