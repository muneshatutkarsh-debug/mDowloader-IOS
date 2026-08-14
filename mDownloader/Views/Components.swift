import SwiftUI
import UIKit

struct MockupSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BrandPalette.secondaryText)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(BrandPalette.primaryText)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(BrandPalette.search)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

struct MockupSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .tracking(0.5)
            .foregroundStyle(BrandPalette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FileTypeIcon: View {
    let fileName: String
    var size: CGFloat = 48

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.43, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(symbolForeground, symbolBackground)
            .frame(width: size, height: size)
            .background(BrandPalette.elevated)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }

    private var symbol: String {
        switch fileName.split(separator: ".").last?.lowercased() {
        case "mp4", "mov", "m4v", "mkv": "movieclapper.fill"
        case "mp3", "wav", "m4a", "aac", "flac": "music.note"
        case "zip", "rar", "7z", "xip", "tar", "gz": "shippingbox.fill"
        case "png", "jpg", "jpeg", "gif", "heic", "webp": "photo.fill"
        case "pdf": "doc.richtext.fill"
        default: "doc.fill"
        }
    }

    private var symbolForeground: Color {
        switch symbol {
        case "movieclapper.fill": .white
        case "music.note": .cyan
        case "shippingbox.fill": .orange
        case "photo.fill": .green
        case "doc.richtext.fill": .red
        default: BrandPalette.secondaryText
        }
    }

    private var symbolBackground: Color {
        symbol == "movieclapper.fill" ? .teal : BrandPalette.elevated
    }
}

struct BrandedProgressBar: View {
    let progress: Double
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let clamped = progress.clamped(to: 0...1)
            let filledWidth = proxy.size.width * clamped
            let knobDiameter = height + 8
            let maxKnobOffset = max(proxy.size.width - knobDiameter, CGFloat.zero)
            ZStack(alignment: .leading) {
                Capsule().fill(BrandPalette.secondaryText.opacity(0.25))
                Capsule()
                    .fill(BrandPalette.progressGradient)
                    .frame(width: max(filledWidth, clamped > 0 ? height : 0))
                if clamped > 0, clamped < 1 {
                    Circle()
                        .fill(BrandPalette.arrowRed)
                        .overlay(Circle().stroke(.white, lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                        .frame(width: knobDiameter, height: knobDiameter)
                        .offset(x: (filledWidth - knobDiameter / 2).clamped(to: CGFloat.zero...maxKnobOffset))
                }
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Download progress")
        .accessibilityValue("\(Int(progress.clamped(to: 0...1) * 100)) percent")
    }
}

struct DownloadRow: View {
    @EnvironmentObject private var manager: DownloadManager
    let record: DownloadRecord

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            FileTypeIcon(fileName: record.fileName)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(record.fileName)
                        .font(.headline)
                        .foregroundStyle(BrandPalette.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    trailingStatus
                }

                Text(detailText)
                    .font(.subheadline)
                    .foregroundStyle(BrandPalette.secondaryText)
                    .lineLimit(1)

                if record.state.isActive || record.state == .completed {
                    BrandedProgressBar(progress: record.progress)
                        .padding(.top, 5)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
        .contextMenu {
            if record.state == .downloading {
                Button("Pause", systemImage: "pause.fill") { manager.pause(record) }
            }
            if record.state == .paused || record.state == .failed {
                Button(record.state == .paused ? "Resume" : "Retry", systemImage: "play.fill") {
                    record.state == .paused ? manager.resume(record) : manager.retry(record)
                }
            }
            if record.state.isActive {
                Button("Cancel", systemImage: "xmark", role: .destructive) { manager.cancel(record) }
            }
            Button("Delete", systemImage: "trash", role: .destructive) { manager.delete(record) }
        }
    }

    @ViewBuilder
    private var trailingStatus: some View {
        switch record.state {
        case .downloading, .queued:
            HStack(spacing: 8) {
                Text(record.percentText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BrandPalette.primaryText)
                Button { manager.pause(record) } label: {
                    Image(systemName: "pause.fill")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Pause \(record.fileName)")
            }
        case .paused:
            Button { manager.resume(record) } label: {
                Label("Resume", systemImage: "play.fill")
                    .labelStyle(.iconOnly)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Resume \(record.fileName)")
        case .completed:
            Image(systemName: "checkmark")
                .font(.headline.weight(.bold))
                .foregroundStyle(BrandPalette.accent)
        case .failed:
            Button { manager.retry(record) } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Retry \(record.fileName)")
        case .cancelled:
            Image(systemName: "xmark")
                .foregroundStyle(BrandPalette.secondaryText)
        }
    }

    private var detailText: String {
        switch record.state {
        case .downloading:
            return "\(record.sizeText) • \(record.speedText)"
        case .queued:
            return "Waiting for connection"
        case .paused:
            return "\(record.sizeText) • Paused"
        case .completed:
            return "\(record.sizeText) • Completed"
        case .failed:
            return record.errorMessage ?? "Download failed"
        case .cancelled:
            return "Cancelled"
        }
    }
}

struct DownloadInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var manager: DownloadManager
    @State private var link = UIPasteboard.general.string ?? ""
    @State private var fileName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Download link") {
                    TextField("https://example.com/file.zip", text: $link, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
                Section("Filename (optional)") {
                    TextField("Use the server filename", text: $fileName)
                }
                Section {
                    Label("Links shared from Safari and other browsers can also be sent directly to mDownloader.", systemImage: "square.and.arrow.up")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Download")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") {
                        if manager.startDownload(from: link, suggestedName: fileName) != nil { dismiss() }
                    }
                    .fontWeight(.semibold)
                    .disabled(link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
