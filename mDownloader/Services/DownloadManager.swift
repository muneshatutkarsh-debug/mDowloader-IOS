import Foundation
import UIKit
import UserNotifications
import WidgetKit

final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var records: [DownloadRecord]
    @Published var lastErrorMessage: String?

    private let storage = SharedStorage.shared
    private var backgroundCompletionHandlers: [String: () -> Void] = [:]
    private var speedSamples: [UUID: (date: Date, bytes: Int64)] = [:]

    private lazy var primarySession = makeSession(identifier: AppGroup.primaryBackgroundSession)
    private lazy var shareSession = makeSession(identifier: AppGroup.shareBackgroundSession)

    private override init() {
        let stored = SharedStorage.shared.loadRecords().sorted { $0.createdAt > $1.createdAt }
        if ProcessInfo.processInfo.environment["MDOWNLOADER_DEMO"] == "1" {
            records = Self.demoRecords
            SharedStorage.shared.saveRecords(Self.demoRecords)
        } else {
            records = stored
        }
        super.init()
    }

    var activeRecords: [DownloadRecord] {
        records.filter(\.state.isActive)
    }

    var completedRecords: [DownloadRecord] {
        records.filter { $0.state == .completed }
    }

    func restoreBackgroundTasks() {
        refreshFromDisk()
        restoreTasks(in: primarySession)
        restoreTasks(in: shareSession)
    }

    func refreshFromDisk() {
        let diskRecords = storage.loadRecords().sorted { $0.createdAt > $1.createdAt }
        DispatchQueue.main.async {
            self.records = diskRecords
        }
    }

    @discardableResult
    func startDownload(from input: String, suggestedName: String? = nil) -> UUID? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            lastErrorMessage = "Enter a valid HTTP or HTTPS link."
            return nil
        }

        let fileName = normalizedFileName(suggestedName, from: url)
        var record = DownloadRecord(sourceURL: url.absoluteString, fileName: fileName)
        record.state = .downloading
        record.updatedAt = Date()
        upsertOnMain(record)

        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("mDownloader/1.0", forHTTPHeaderField: "User-Agent")

        let task = primarySession.downloadTask(with: request)
        task.taskDescription = record.id.uuidString
        task.resume()
        requestNotificationPermissionIfNeeded()
        Task { @MainActor in
            LiveActivityController.shared.start(for: record)
        }
        return record.id
    }

    func pause(_ record: DownloadRecord) {
        findTask(for: record.id) { task in
            guard let task = task as? URLSessionDownloadTask else { return }
            task.cancel { resumeData in
                if let resumeData { self.storage.saveResumeData(resumeData, for: record.id) }
                self.updateRecord(id: record.id) {
                    $0.state = .paused
                    $0.bytesPerSecond = 0
                    $0.estimatedSecondsRemaining = nil
                }
            }
        }
    }

    func resume(_ record: DownloadRecord) {
        guard let source = record.source else { return }
        let task: URLSessionDownloadTask
        if let resumeData = storage.resumeData(for: record.id) {
            task = primarySession.downloadTask(withResumeData: resumeData)
        } else {
            task = primarySession.downloadTask(with: source)
        }
        task.taskDescription = record.id.uuidString
        storage.deleteResumeData(for: record.id)
        updateRecord(id: record.id) {
            $0.state = .downloading
            $0.errorMessage = nil
        }
        task.resume()
    }

    func cancel(_ record: DownloadRecord) {
        findTask(for: record.id) { $0?.cancel() }
        storage.deleteResumeData(for: record.id)
        updateRecord(id: record.id) {
            $0.state = .cancelled
            $0.bytesPerSecond = 0
            $0.estimatedSecondsRemaining = nil
        }
    }

    func retry(_ record: DownloadRecord) {
        storage.deleteResumeData(for: record.id)
        guard let source = record.source else { return }
        let task = primarySession.downloadTask(with: source)
        task.taskDescription = record.id.uuidString
        updateRecord(id: record.id) {
            $0.state = .downloading
            $0.progress = 0
            $0.bytesWritten = 0
            $0.totalBytes = 0
            $0.errorMessage = nil
            $0.completedAt = nil
            $0.localFileName = nil
        }
        task.resume()
    }

    func delete(_ record: DownloadRecord) {
        cancel(record)
        if let fileURL = storage.localURL(for: record) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        DispatchQueue.main.async {
            self.records.removeAll { $0.id == record.id }
            self.persistAndRefreshWidgets()
        }
    }

    func localURL(for record: DownloadRecord) -> URL? {
        storage.localURL(for: record)
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "mdownloader" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let link = components?.queryItems?.first(where: { $0.name == "url" })?.value {
            _ = startDownload(from: link)
        } else if let clipboard = UIPasteboard.general.string {
            _ = startDownload(from: clipboard)
        }
    }

    func adoptBackgroundSession(identifier: String, completionHandler: @escaping () -> Void) {
        backgroundCompletionHandlers[identifier] = completionHandler
        if identifier == AppGroup.shareBackgroundSession {
            _ = shareSession
        } else {
            _ = primarySession
        }
    }

    private func makeSession(identifier: String) -> URLSession {
        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        configuration.sharedContainerIdentifier = AppGroup.identifier
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 8
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60 * 60 * 24 * 7
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    private func restoreTasks(in session: URLSession) {
        session.getAllTasks { tasks in
            for task in tasks {
                guard let id = task.taskDescription.flatMap(UUID.init(uuidString:)) else { continue }
                self.updateRecord(id: id) { record in
                    if task.state == .running { record.state = .downloading }
                    if task.state == .suspended { record.state = .paused }
                }
            }
        }
    }

    private func findTask(for id: UUID, completion: @escaping (URLSessionTask?) -> Void) {
        let sessions = [primarySession, shareSession]
        let group = DispatchGroup()
        let lock = NSLock()
        var found: URLSessionTask?
        for session in sessions {
            group.enter()
            session.getAllTasks { tasks in
                lock.lock()
                if found == nil {
                    found = tasks.first { $0.taskDescription == id.uuidString }
                }
                lock.unlock()
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(found) }
    }

    private func normalizedFileName(_ proposed: String?, from url: URL) -> String {
        if let proposed, !proposed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return proposed
        }
        let lastPath = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        return lastPath.isEmpty || lastPath == "/" ? "Download-\(Int(Date().timeIntervalSince1970))" : lastPath
    }

    private func updateRecord(id: UUID, mutation: @escaping (inout DownloadRecord) -> Void) {
        DispatchQueue.main.async {
            if let index = self.records.firstIndex(where: { $0.id == id }) {
                mutation(&self.records[index])
                self.records[index].updatedAt = Date()
            } else if var record = self.storage.loadRecords().first(where: { $0.id == id }) {
                mutation(&record)
                record.updatedAt = Date()
                self.records.insert(record, at: 0)
            } else {
                return
            }
            guard let record = self.records.first(where: { $0.id == id }) else { return }
            self.persistAndRefreshWidgets()
            Task { @MainActor in
                if record.state == .completed || record.state == .failed || record.state == .cancelled {
                    LiveActivityController.shared.end(record)
                } else {
                    LiveActivityController.shared.update(record)
                }
            }
        }
    }

    private func upsertOnMain(_ record: DownloadRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.insert(record, at: 0)
        }
        persistAndRefreshWidgets()
    }

    private func persistAndRefreshWidgets() {
        storage.saveRecords(records)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func requestNotificationPermissionIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    private func notifyCompletion(for record: DownloadRecord) {
        let content = UNMutableNotificationContent()
        content.title = "Download complete"
        content.body = record.fileName
        content.sound = .default
        let request = UNNotificationRequest(identifier: record.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static var demoRecords: [DownloadRecord] {
        let now = Date()
        return [
            DownloadRecord(
                sourceURL: "https://example.com/BigBuckBunny4K.mp4",
                fileName: "Big Buck Bunny 4K.mp4",
                state: .downloading,
                progress: 0.62,
                bytesWritten: 260_400_000,
                totalBytes: 420_000_000,
                bytesPerSecond: 12_400_000,
                estimatedSecondsRemaining: 180,
                createdAt: now,
                updatedAt: now
            ),
            DownloadRecord(
                sourceURL: "https://example.com/Xcode_16.4.xip",
                fileName: "Xcode_16.4.xip",
                state: .downloading,
                progress: 0.34,
                bytesWritten: 2_450_000_000,
                totalBytes: 7_200_000_000,
                bytesPerSecond: 1_800_000,
                estimatedSecondsRemaining: 2_640,
                createdAt: now.addingTimeInterval(-60),
                updatedAt: now
            ),
            DownloadRecord(
                sourceURL: "https://example.com/lofi-mix.zip",
                fileName: "lofi-mix.zip",
                state: .completed,
                progress: 1,
                bytesWritten: 86_000_000,
                totalBytes: 86_000_000,
                createdAt: now.addingTimeInterval(-120),
                updatedAt: now,
                completedAt: now,
                localFileName: "lofi-mix.zip"
            ),
            DownloadRecord(
                sourceURL: "https://example.com/Invoice_July.pdf",
                fileName: "Invoice_July.pdf",
                state: .completed,
                progress: 1,
                bytesWritten: 240_000,
                totalBytes: 240_000,
                createdAt: now.addingTimeInterval(-86_400),
                updatedAt: now.addingTimeInterval(-86_400),
                completedAt: now.addingTimeInterval(-86_400),
                localFileName: "Invoice_July.pdf"
            ),
            DownloadRecord(
                sourceURL: "https://example.com/wallpaper_5k.png",
                fileName: "wallpaper_5k.png",
                state: .completed,
                progress: 1,
                bytesWritten: 5_100_000,
                totalBytes: 5_100_000,
                createdAt: now.addingTimeInterval(-172_800),
                updatedAt: now.addingTimeInterval(-172_800),
                completedAt: now.addingTimeInterval(-172_800),
                localFileName: "wallpaper_5k.png"
            )
        ]
    }
}

extension DownloadManager: URLSessionDownloadDelegate, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let id = downloadTask.taskDescription.flatMap(UUID.init(uuidString:)) else { return }
        let now = Date()
        let previous = speedSamples[id]
        let speed: Double
        if let previous, now.timeIntervalSince(previous.date) > 0 {
            speed = Double(totalBytesWritten - previous.bytes) / now.timeIntervalSince(previous.date)
        } else {
            speed = 0
        }
        speedSamples[id] = (now, totalBytesWritten)
        let total = max(totalBytesExpectedToWrite, 0)
        let progress = total > 0 ? Double(totalBytesWritten) / Double(total) : 0
        let remaining = speed > 0 && total > totalBytesWritten
            ? Double(total - totalBytesWritten) / speed
            : nil

        updateRecord(id: id) {
            $0.state = .downloading
            $0.bytesWritten = totalBytesWritten
            $0.totalBytes = total
            $0.progress = progress.clamped(to: 0...1)
            $0.bytesPerSecond = max(speed, 0)
            $0.estimatedSecondsRemaining = remaining
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let id = downloadTask.taskDescription.flatMap(UUID.init(uuidString:)) else { return }
        let existing = storage.loadRecords().first(where: { $0.id == id })
        let suggestedName = downloadTask.response?.suggestedFilename ?? existing?.fileName ?? "Download"
        let destination = storage.uniqueDestination(for: suggestedName)

        do {
            try FileManager.default.moveItem(at: location, to: destination)
            storage.deleteResumeData(for: id)
            updateRecord(id: id) {
                $0.fileName = destination.lastPathComponent
                $0.localFileName = destination.lastPathComponent
                $0.state = .completed
                $0.progress = 1
                $0.bytesPerSecond = 0
                $0.estimatedSecondsRemaining = nil
                $0.completedAt = Date()
                $0.errorMessage = nil
            }
            if var record = existing {
                record.fileName = destination.lastPathComponent
                notifyCompletion(for: record)
            }
        } catch {
            updateRecord(id: id) {
                $0.state = .failed
                $0.errorMessage = error.localizedDescription
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error,
              let id = task.taskDescription.flatMap(UUID.init(uuidString:)) else { return }
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }
        if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            storage.saveResumeData(resumeData, for: id)
        }
        updateRecord(id: id) {
            $0.state = .failed
            $0.bytesPerSecond = 0
            $0.estimatedSecondsRemaining = nil
            $0.errorMessage = error.localizedDescription
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        guard let identifier = session.configuration.identifier else { return }
        DispatchQueue.main.async {
            let completion = self.backgroundCompletionHandlers.removeValue(forKey: identifier)
            completion?()
        }
    }
}
