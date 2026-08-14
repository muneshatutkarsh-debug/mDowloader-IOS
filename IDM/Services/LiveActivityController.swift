import ActivityKit
import Foundation

final class LiveActivityController {
    static let shared = LiveActivityController()

    private var currentActivity: Activity<DownloadActivityAttributes>?
    private var currentDownloadID: UUID?
    private var lastUpdate = Date.distantPast

    private init() {}

    func start(for item: DownloadItem) {
        guard #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let existing = Activity<DownloadActivityAttributes>.activities.first(where: { $0.attributes.downloadID == item.id }) {
            currentActivity = existing
            currentDownloadID = item.id
            update(for: item, force: true)
            return
        }

        guard currentActivity == nil else { return }

        let attributes = DownloadActivityAttributes(
            downloadID: item.id,
            filename: item.filename,
            fileType: item.fileExtensionLabel,
            isOriginal: ThemeManager.storedIsOriginal
        )
        let state = contentState(for: item)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            currentDownloadID = item.id
        } catch {
            print("Unable to start Live Activity: \(error.localizedDescription)")
        }
    }

    func update(for item: DownloadItem, force: Bool = false) {
        guard #available(iOS 16.2, *), item.id == currentDownloadID else { return }
        guard force || Date().timeIntervalSince(lastUpdate) >= 1 else { return }
        lastUpdate = Date()

        guard let activity = currentActivity ?? Activity<DownloadActivityAttributes>.activities.first(where: { $0.attributes.downloadID == item.id }) else { return }
        currentActivity = activity
        let content = ActivityContent(state: contentState(for: item), staleDate: Date().addingTimeInterval(120))
        Task { await activity.update(content) }
    }

    func end(for item: DownloadItem) {
        guard #available(iOS 16.2, *), item.id == currentDownloadID else { return }
        guard let activity = currentActivity ?? Activity<DownloadActivityAttributes>.activities.first(where: { $0.attributes.downloadID == item.id }) else { return }

        let finalContent = ActivityContent(state: contentState(for: item), staleDate: nil)
        let policy: ActivityUIDismissalPolicy = item.status == .completed ? .after(Date().addingTimeInterval(90)) : .immediate
        Task { await activity.end(finalContent, dismissalPolicy: policy) }
        currentActivity = nil
        currentDownloadID = nil
    }

    private func contentState(for item: DownloadItem) -> DownloadActivityAttributes.ContentState {
        DownloadActivityAttributes.ContentState(
            progress: item.progress,
            speed: item.formattedSpeed,
            compactSpeed: item.compactSpeed,
            timeRemaining: item.formattedTimeRemaining,
            status: item.status.title
        )
    }
}

