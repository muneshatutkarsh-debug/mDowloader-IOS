import ActivityKit
import Foundation

@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var lastUpdate: [UUID: Date] = [:]

    private init() {}

    func start(for record: DownloadRecord) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity(for: record.id) == nil else { return }

        let attributes = DownloadActivityAttributes(downloadID: record.id.uuidString)
        let content = ActivityContent(state: state(for: record), staleDate: nil)
        do {
            _ = try Activity<DownloadActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            lastUpdate[record.id] = Date()
        } catch {
            // Downloads continue normally if the system declines a Live Activity.
        }
    }

    func update(_ record: DownloadRecord, force: Bool = false) {
        guard let activity = activity(for: record.id) else {
            if record.state == .downloading { start(for: record) }
            return
        }

        let now = Date()
        if !force, let previous = lastUpdate[record.id], now.timeIntervalSince(previous) < 1 { return }
        lastUpdate[record.id] = now
        let content = ActivityContent(state: state(for: record), staleDate: nil)
        Task { await activity.update(content) }
    }

    func end(_ record: DownloadRecord) {
        guard let activity = activity(for: record.id) else { return }
        lastUpdate.removeValue(forKey: record.id)
        let finalContent = ActivityContent(state: state(for: record), staleDate: nil)
        Task {
            await activity.end(finalContent, dismissalPolicy: .default)
        }
    }

    private func activity(for id: UUID) -> Activity<DownloadActivityAttributes>? {
        Activity<DownloadActivityAttributes>.activities.first {
            $0.attributes.downloadID == id.uuidString
        }
    }

    private func state(for record: DownloadRecord) -> DownloadActivityAttributes.ContentState {
        DownloadActivityAttributes.ContentState(
            fileName: record.fileName,
            progress: record.progress,
            speedText: record.speedText,
            remainingText: record.remainingText ?? "Calculating…",
            statusText: statusText(for: record.state)
        )
    }

    private func statusText(for state: DownloadState) -> String {
        switch state {
        case .queued: "Queued"
        case .downloading: "Downloading"
        case .paused: "Paused"
        case .completed: "Completed"
        case .failed: "Download failed"
        case .cancelled: "Cancelled"
        }
    }
}

