import SwiftUI

struct FilesView: View {
    @EnvironmentObject private var manager: DownloadManager
    @State private var searchText = ""
    @State private var sharingURL: URL?

    private var files: [DownloadRecord] {
        manager.completedRecords.filter {
            searchText.isEmpty || $0.fileName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Files")
                    .font(.largeTitle.bold())
                    .foregroundStyle(BrandPalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                MockupSearchField(placeholder: "Search files", text: $searchText)
                MockupSectionLabel(text: "All Files")

                if files.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 46))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(BrandPalette.accent)
                        Text("Downloaded files appear here")
                            .font(.headline)
                            .foregroundStyle(BrandPalette.primaryText)
                        Text("Tap a file to export, save, or open it in another app.")
                            .font(.subheadline)
                            .foregroundStyle(BrandPalette.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                    .padding(.horizontal, 24)
                    .mDownloaderCard()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(files.enumerated()), id: \.element.id) { index, record in
                            Button {
                                sharingURL = manager.localURL(for: record)
                            } label: {
                                HStack(spacing: 14) {
                                    FileTypeIcon(fileName: record.fileName)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(record.fileName)
                                            .font(.headline)
                                            .foregroundStyle(BrandPalette.primaryText)
                                            .lineLimit(1)
                                        Text("\(record.sizeText) • \(formattedDate(record.completedAt ?? record.updatedAt))")
                                            .font(.subheadline)
                                            .foregroundStyle(BrandPalette.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(BrandPalette.secondaryText)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 15)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if let url = manager.localURL(for: record) {
                                    ShareLink(item: url) {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    manager.delete(record)
                                }
                            }
                            if index < files.count - 1 {
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
        .sheet(isPresented: Binding(
            get: { sharingURL != nil },
            set: { if !$0 { sharingURL = nil } }
        )) {
            if let sharingURL {
                ActivityShareSheet(items: [sharingURL])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

