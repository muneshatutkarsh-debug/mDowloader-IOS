import SwiftUI

private enum DownloadFilter: String, CaseIterable {
    case all = "All"
    case downloading = "Downloading"
    case completed = "Completed"
}

struct DownloadsView: View {
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var theme: ThemeManager
    @State private var filter: DownloadFilter = .all
    @State private var showAddDownload = false
    @State private var selectedDownload: UUID?
    @Namespace private var segmentNS

    private var filteredItems: [DownloadItem] {
        switch filter {
        case .all: downloads.items
        case .downloading: downloads.items.filter { [.queued, .downloading, .paused].contains($0.status) }
        case .completed: downloads.items.filter { $0.status == .completed }
        }
    }

    private var aggregateSpeed: Double {
        downloads.items.filter { $0.status == .downloading }.reduce(0) { $0 + $1.bytesPerSecond }
    }

    var body: some View {
        ZStack {
            IDMBackground()
            List {
                header
                    .listRowInsets(EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20))
                    .downloadListRowStyle()

                filterBar
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 16, trailing: 20))
                    .downloadListRowStyle()

                speedCard
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 16, trailing: 20))
                    .downloadListRowStyle()

                if filteredItems.isEmpty {
                    emptyState
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 16, trailing: 20))
                        .downloadListRowStyle()
                } else {
                    ForEach(filteredItems) { item in
                        DownloadRow(item: item) { primaryAction(for: item) }
                            .contentShape(Rectangle())
                            .onTapGesture { selectedDownload = item.id }
                            .contextMenu {
                                if item.status == .downloading || item.status == .queued {
                                    Button("Pause", systemImage: "pause") { downloads.pause(item.id) }
                                } else if item.status != .completed {
                                    Button("Resume", systemImage: "play") { downloads.resume(item.id) }
                                }
                                Button("Remove from history", systemImage: "trash", role: .destructive) { downloads.remove(item.id) }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    downloads.remove(item.id)
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 16, trailing: 20))
                            .downloadListRowStyle()
                    }
                }

                Color.clear
                    .frame(height: 105)
                    .downloadListRowStyle()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddDownload) { AddDownloadSheet() }
        .navigationDestination(item: $selectedDownload) { id in
            DownloadDetailView(downloadID: id)
        }
    }

    private var header: some View {
        HStack {
            PageTitle(title: "Downloads")
            Button { showAddDownload = true } label: {
                Image(systemName: "plus").font(.title2.weight(.medium)).frame(width: 50, height: 50).glassCard(radius: 25)
            }
            .buttonStyle(.plain)
            Menu {
                Button("Pause All", systemImage: "pause") { downloads.pauseAll() }
                Button("Resume All", systemImage: "play") { downloads.resumeAll() }
                Button("Clear Completed History", systemImage: "checkmark.circle") { downloads.clearCompletedHistory() }
            } label: {
                Image(systemName: "ellipsis").font(.title2.weight(.medium)).frame(width: 50, height: 50).glassCard(radius: 25)
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            ForEach(DownloadFilter.allCases, id: \.self) { value in
                let isSelected = filter == value
                Text(value.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.idmSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Color.idmAccent)
                                .matchedGeometryEffect(id: "selectedSegment", in: segmentNS)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.snappy(duration: 0.3)) { filter = value }
                    }
            }
        }
        .padding(4)
        .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
    }

    private var speedCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.idmAccent)
                Image(systemName: "wifi").font(.title2.weight(.bold)).foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text("Transfer Speed").font(.subheadline).foregroundStyle(Color.idmSecondary)
                Text(aggregateSpeed > 0 ? ByteCountFormatter.string(fromByteCount: Int64(aggregateSpeed), countStyle: .file) + "/s" : "Ready")
                    .font(.title3.bold()).foregroundStyle(Color.idmInk)
            }
            Spacer()
            Image(systemName: "chart.bar.fill").foregroundStyle(Color.idmBlue).font(.title2)
        }
        .padding(16)
        .glassCard(radius: 24)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            SymbolTile(symbol: "arrow.down.circle", size: 58)
            Text(filter == .completed ? "No completed downloads" : "Ready for your first download")
                .font(.headline).foregroundStyle(Color.idmInk)
            Text("Add a direct link, or share a link to mDownloader from any app to begin.")
                .font(.footnote).foregroundStyle(Color.idmSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button { showAddDownload = true } label: {
                Text("Add Download").font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent).tint(.idmBlue)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 24)
        .glassCard(radius: 26)
    }

    private func primaryAction(for item: DownloadItem) {
        switch item.status {
        case .downloading, .queued: downloads.pause(item.id)
        case .paused, .failed, .cancelled: downloads.resume(item.id)
        case .completed: break
        }
    }
}

private extension View {
    func downloadListRowStyle() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
