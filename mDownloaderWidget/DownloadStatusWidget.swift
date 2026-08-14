import SwiftUI
import WidgetKit

private struct DownloadWidgetEntry: TimelineEntry {
    let date: Date
    let record: DownloadRecord?
}

private struct DownloadTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DownloadWidgetEntry {
        DownloadWidgetEntry(
            date: Date(),
            record: DownloadRecord(
                sourceURL: "https://example.com/video.mp4",
                fileName: "Big Buck Bunny 4K.mp4",
                state: .downloading,
                progress: 0.62,
                bytesWritten: 260_000_000,
                totalBytes: 420_000_000,
                bytesPerSecond: 12_400_000,
                estimatedSecondsRemaining: 180
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DownloadWidgetEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DownloadWidgetEntry>) -> Void) {
        let current = entry()
        completion(Timeline(entries: [current], policy: .after(Date().addingTimeInterval(60))))
    }

    private func entry() -> DownloadWidgetEntry {
        let records = SharedStorage.shared.loadRecords()
        let record = records.first(where: { $0.state.isActive })
            ?? records.filter { $0.state == .completed }.max(by: { $0.updatedAt < $1.updatedAt })
        return DownloadWidgetEntry(date: Date(), record: record)
    }
}

struct DownloadStatusWidget: Widget {
    let kind = "mDownloaderStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DownloadTimelineProvider()) { entry in
            DownloadWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.035, green: 0.075, blue: 0.18)
                }
        }
        .configurationDisplayName("Download Status")
        .description("See your current download progress and speed.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct DownloadWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DownloadWidgetEntry

    var body: some View {
        Link(destination: URL(string: "mdownloader://open")!) {
            if let record = entry.record {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: record.state == .completed ? "checkmark" : "arrow.down")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color(red: 0.22, green: 0.36, blue: 0.68))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        if family == .systemMedium {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.fileName)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(record.state == .completed ? "Completed" : record.speedText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Spacer()
                            Text(record.percentText)
                                .font(.headline.bold())
                        }
                    }
                    if family == .systemSmall {
                        Text(record.fileName)
                            .font(.headline)
                            .lineLimit(2)
                    }
                    ProgressView(value: record.progress)
                        .tint(Color(red: 0.39, green: 0.57, blue: 0.92))
                    if family == .systemMedium {
                        HStack {
                            Text(record.speedText)
                            Spacer()
                            Text(record.remainingText ?? record.percentText)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color(red: 0.39, green: 0.57, blue: 0.92))
                    Text("mDownloader")
                        .font(.headline)
                    Text("Share a link to start downloading.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

