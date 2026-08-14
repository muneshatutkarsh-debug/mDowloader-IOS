import ActivityKit
import SwiftUI
import WidgetKit

struct DownloadLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            LockScreenDownloadView(state: context.state)
                .activityBackgroundTint(Color(red: 0.035, green: 0.075, blue: 0.18))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "arrow.down")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(red: 0.21, green: 0.35, blue: 0.67))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.fileName)
                            .font(.headline)
                            .lineLimit(1)
                        Text("\(context.state.statusText) • \(context.state.speedText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        IslandProgressBar(progress: context.state.progress)
                        HStack {
                            Text(context.state.speedText)
                            Spacer()
                            Text(context.state.remainingText)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress.clamped(to: 0...1) * 100))%")
                        .font(.headline.bold())
                }
            } compactLeading: {
                ProgressView(value: context.state.progress)
                    .progressViewStyle(.circular)
                    .tint(Color(red: 0.39, green: 0.57, blue: 0.92))
            } compactTrailing: {
                Text(context.state.speedText.replacingOccurrences(of: " ", with: ""))
                    .font(.caption2.bold())
                    .foregroundStyle(Color(red: 0.39, green: 0.57, blue: 0.92))
                    .frame(maxWidth: 60)
            } minimal: {
                Image(systemName: "arrow.down")
                    .foregroundStyle(Color(red: 0.39, green: 0.57, blue: 0.92))
            }
            .keylineTint(Color(red: 0.39, green: 0.57, blue: 0.92))
            .widgetURL(URL(string: "mdownloader://open"))
        }
    }
}

private struct LockScreenDownloadView: View {
    let state: DownloadActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.21, green: 0.35, blue: 0.67))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    Text("mDownloader • \(Int(state.progress.clamped(to: 0...1) * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            IslandProgressBar(progress: state.progress)
            HStack {
                Text(state.speedText)
                Spacer()
                Text(state.remainingText)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

private struct IslandProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let clamped = progress.clamped(to: 0...1)
            let width = proxy.size.width * clamped
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.42, green: 0.59, blue: 0.92),
                            Color(red: 0.13, green: 0.25, blue: 0.55)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: max(width, clamped > 0 ? 10 : 0))
                if clamped > 0, clamped < 1 {
                    Circle()
                        .fill(Color(red: 0.95, green: 0.24, blue: 0.36))
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .frame(width: 18, height: 18)
                        .offset(x: (width - 9).clamped(to: 0...max(proxy.size.width - 18, 0)))
                }
            }
        }
        .frame(height: 10)
    }
}

