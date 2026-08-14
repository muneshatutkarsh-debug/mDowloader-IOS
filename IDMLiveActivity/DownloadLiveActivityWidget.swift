import ActivityKit
import SwiftUI
import WidgetKit
import UIKit

@main
struct IDMWidgetBundle: WidgetBundle {
    var body: some Widget {
        DownloadLiveActivityWidget()
    }
}

// MARK: - Palette
// The asset catalog isn't shared with this widget target, so brand colors are
// defined locally. `idmSystemBlue` is the Basic accent; the brand tokens drive
// the Original theme (logo-blue ring, blue gradient bar, red leading ball).
private extension Color {
    /// Basic-theme accent — Apple system blue.
    static let idmSystemBlue = Color(uiColor: .systemBlue)

    /// Original-theme accent (logo blue), adapting to light/dark.
    static let brandBlue = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: CGFloat(0x6E) / 255, green: CGFloat(0x90) / 255, blue: CGFloat(0xE6) / 255, alpha: 1)
            : UIColor(red: CGFloat(0x34) / 255, green: CGFloat(0x54) / 255, blue: CGFloat(0x9A) / 255, alpha: 1)
    })

    static let brandGradTop = Color(.sRGB, red: Double(0x4F) / 255, green: Double(0x72) / 255, blue: Double(0xBE) / 255, opacity: 1)
    static let brandGradBottom = Color(.sRGB, red: Double(0x2E) / 255, green: Double(0x40) / 255, blue: Double(0x88) / 255, opacity: 1)
    static let brandRed = Color(.sRGB, red: Double(0xEC) / 255, green: Double(0x44) / 255, blue: Double(0x5B) / 255, opacity: 1)

    /// Deep logo-blue used to tint the Original lock-screen banner.
    static let brandLockTint = Color(.sRGB, red: Double(0x0B) / 255, green: Double(0x13) / 255, blue: Double(0x30) / 255, opacity: 1)
}

/// Circular progress ring used in the compact + minimal Dynamic Island. The
/// stroke is inset by half its width so it never clips in the tight regions.
private struct ActivityRing: View {
    let progress: Double
    var lineWidth: CGFloat = 4
    var glyph: String? = nil
    var glyphSize: CGFloat = 9
    var tint: Color = .idmSystemBlue

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, clamped))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let glyph {
                Image(systemName: glyph)
                    .font(.system(size: glyphSize, weight: .bold))
                    .foregroundStyle(tint)
            }
        }
        .padding(lineWidth / 2)
    }
}

/// Themed horizontal progress bar for the Original theme: a thicker blue
/// gradient fill led by a small red "arrow" ball. Basic falls back to the
/// system `ProgressView` at the call sites.
private struct ThemedBar: View {
    let progress: Double
    var thickness: CGFloat = 8

    private var clamped: Double { min(max(progress, 0), 1) }
    private var ballD: CGFloat { thickness + 6 }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let fillW = max(0, w * clamped)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: thickness)
                Capsule()
                    .fill(LinearGradient(colors: [.brandGradTop, .brandGradBottom], startPoint: .leading, endPoint: .trailing))
                    .frame(width: fillW, height: thickness)
                if clamped > 0.001 && clamped < 0.999 {
                    Circle()
                        .fill(Color.brandRed)
                        .frame(width: ballD, height: ballD)
                        .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
                        .offset(x: min(fillW, w) - ballD / 2)
                }
            }
            .frame(height: ballD)
        }
        .frame(height: ballD)
    }
}

struct DownloadLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            let original = context.attributes.isOriginal
            LockScreenView(context: context)
                .activityBackgroundTint(original ? Color.brandLockTint : nil)
                .activitySystemActionForegroundColor(original ? Color.brandBlue : Color.idmSystemBlue)
        } dynamicIsland: { context in
            let isDone = context.state.status == "Completed"
            let progress = min(max(context.state.progress, 0), 1)
            let original = context.attributes.isOriginal
            let accent = original ? Color.brandBlue : Color.idmSystemBlue
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(accent)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(progress * 100))%")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(accent)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.filename)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(isDone ? "Download complete" : context.state.status)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        if original {
                            ThemedBar(progress: progress, thickness: 8)
                                .padding(.top, 2)
                        } else {
                            ProgressView(value: progress)
                                .tint(accent)
                        }
                        HStack(spacing: 8) {
                            Label(context.state.speed, systemImage: "speedometer")
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if !isDone {
                                Label(context.state.timeRemaining, systemImage: "clock")
                                    .lineLimit(1)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
                }
            } compactLeading: {
                ActivityRing(progress: progress, lineWidth: 3,
                             glyph: isDone ? "checkmark" : "arrow.down", glyphSize: 8,
                             tint: accent)
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accent)
                } else {
                    Text(context.state.compactSpeed)
                        .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 62, alignment: .trailing)
                }
            } minimal: {
                ActivityRing(progress: progress, lineWidth: 3,
                             glyph: isDone ? "checkmark" : "arrow.down", glyphSize: 7,
                             tint: accent)
                    .frame(width: 18, height: 18)
            }
            .widgetURL(URL(string: "idm://download/\(context.attributes.downloadID.uuidString)"))
            .keylineTint(accent)
        }
    }
}

/// Lock-screen / banner presentation.
private struct LockScreenView: View {
    let context: ActivityViewContext<DownloadActivityAttributes>

    private var isDone: Bool { context.state.status == "Completed" }
    private var progress: Double { min(max(context.state.progress, 0), 1) }
    private var percent: Int { Int(progress * 100) }
    private var original: Bool { context.attributes.isOriginal }
    private var accent: Color { original ? .brandBlue : .idmSystemBlue }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(context.attributes.filename)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    Text(isDone ? "Done" : "\(percent)%")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(accent)
                }
                if original {
                    ThemedBar(progress: progress, thickness: 7)
                } else {
                    ProgressView(value: progress)
                        .tint(accent)
                }
                HStack {
                    Label(isDone ? "Saved to Downloads" : context.state.speed,
                          systemImage: isDone ? "checkmark.circle.fill" : "arrow.down.circle")
                        .lineLimit(1)
                    Spacer()
                    if !isDone {
                        Text(context.state.timeRemaining)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}
