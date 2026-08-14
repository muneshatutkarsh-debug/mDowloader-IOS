import SwiftUI

struct DownloadRow: View {
    let item: DownloadItem
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            EmojiTile(emoji: item.kind.emoji, size: 64)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.filename)
                        .font(.headline)
                        .foregroundStyle(Color.idmInk)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(item.status == .downloading ? item.formattedSpeed : item.status.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.status == .failed ? .red : Color.idmBlue)
                }

                Text("\(item.formattedTotal)  •  \(item.fileExtensionLabel)")
                    .font(.subheadline)
                    .foregroundStyle(Color.idmSecondary)

                HStack(spacing: 10) {
                    BlueProgressView(progress: item.status == .completed ? 1 : item.progress)
                    Text("\(Int((item.status == .completed ? 1 : item.progress) * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.idmSecondary)
                        .frame(width: 42, alignment: .trailing)
                }

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(Color.idmSecondary)
                    .lineLimit(1)
            }

            Button(action: action) {
                Image(systemName: actionSymbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.idmBlue)
                    .frame(width: 46, height: 46)
                    .background(.thinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.idmHairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .glassCard(radius: 24)
    }

    private var actionSymbol: String {
        switch item.status {
        case .downloading, .queued: "pause.fill"
        case .completed: "checkmark"
        default: "play.fill"
        }
    }

    private var detailText: String {
        switch item.status {
        case .completed: "\(item.formattedWritten)  •  Completed"
        case .failed: item.errorMessage ?? "Download failed"
        case .paused: "\(item.formattedWritten)  •  Paused"
        case .cancelled: "Cancelled"
        case .queued: "Waiting for a transfer slot"
        case .downloading: "\(item.formattedWritten) / \(item.formattedTotal)  •  \(item.formattedTimeRemaining) left"
        }
    }
}
