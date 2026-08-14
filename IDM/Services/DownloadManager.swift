import Combine
import Foundation
import UIKit
import UserNotifications

final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    static let backgroundSessionIdentifier = "com.munesh.IDM.background-downloads"

    @Published private(set) var items: [DownloadItem] = []

    private var session: URLSession!
    private var speedSamples: [UUID: (bytes: Int64, date: Date)] = [:]
    private var lastPersistenceDate = Date.distantPast

    static var downloadsDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let stored = UserDefaults.standard.string(forKey: "downloadFolderName")
        let folderName = (stored?.isEmpty == false) ? stored! : "Downloads"
        let directory = documents.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("IDM", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private var recordsURL: URL { supportDirectory.appendingPathComponent("downloads.json") }

    private override init() {
        super.init()
        UserDefaults.standard.register(defaults: [
            "simultaneousDownloads": 3,
            "wifiOnly": false,
            "notificationsEnabled": true,
            "appTheme": "System",
            "downloadFolderName": "Downloads"
        ])
        loadRecords()
        configureSession()
        restoreBackgroundTasks()
    }

    func reconnectBackgroundSessionIfNeeded(identifier: String) {
        guard identifier == Self.backgroundSessionIdentifier else { return }
        restoreBackgroundTasks()
    }

    func addDownload(url: URL, preferredFilename: String? = nil) {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        requestNotificationPermissionIfNeeded()
        var item = DownloadItem(sourceURL: url, filename: preferredFilename)
        item.status = .queued
        items.insert(item, at: 0)
        persistRecords(force: true)
        pumpQueue()
    }

    func pause(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard items[index].status == .downloading || items[index].status == .queued else { return }

        if items[index].status == .queued, items[index].taskIdentifier == nil {
            items[index].status = .paused
            persistRecords(force: true)
            return
        }

        items[index].status = .paused
        items[index].bytesPerSecond = 0
        persistRecords(force: true)

        session.getAllTasks { [weak self] tasks in
            guard let self else { return }
            guard let task = tasks.first(where: { $0.taskDescription == id.uuidString }) as? URLSessionDownloadTask else {
                DispatchQueue.main.async { self.clearTaskIdentifier(for: id); self.pumpQueue() }
                return
            }
            task.cancel(byProducingResumeData: { resumeData in
                if let resumeData { try? resumeData.write(to: self.resumeDataURL(for: id), options: .atomic) }
                DispatchQueue.main.async {
                    self.clearTaskIdentifier(for: id)
                    self.persistRecords(force: true)
                    self.pumpQueue()
                }
            })
        }
    }

    func resume(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard [.paused, .failed, .cancelled].contains(items[index].status) else { return }
        items[index].status = .queued
        items[index].errorMessage = nil
        persistRecords(force: true)
        pumpQueue()
    }

    func cancel(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = .cancelled
        items[index].bytesPerSecond = 0
        items[index].secondsRemaining = nil
        items[index].taskIdentifier = nil
        try? FileManager.default.removeItem(at: resumeDataURL(for: id))
        let snapshot = items[index]
        LiveActivityController.shared.end(for: snapshot)
        persistRecords(force: true)

        session.getAllTasks { tasks in
            tasks.first(where: { $0.taskDescription == id.uuidString })?.cancel()
        }
        pumpQueue()
    }

    func remove(_ id: UUID) {
        session.getAllTasks { tasks in
            tasks.first(where: { $0.taskDescription == id.uuidString })?.cancel()
        }
        try? FileManager.default.removeItem(at: resumeDataURL(for: id))
        items.removeAll { $0.id == id }
        persistRecords(force: true)
        pumpQueue()
    }

    func pauseAll() {
        items.filter { $0.status == .downloading || $0.status == .queued }.forEach { pause($0.id) }
    }

    func resumeAll() {
        let ids = items.filter { $0.status == .paused || $0.status == .failed }.map(\.id)
        for id in ids {
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index].status = .queued
                items[index].errorMessage = nil
            }
        }
        persistRecords(force: true)
        pumpQueue()
    }

    func clearCompletedHistory() {
        items.removeAll { $0.status == .completed || $0.status == .cancelled }
        persistRecords(force: true)
    }

    func applyTransferSettings() {
        pumpQueue()
    }

    @discardableResult
    func clearCache() -> Int64 {
        let urls = (try? FileManager.default.contentsOfDirectory(at: supportDirectory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        var cleared: Int64 = 0
        for url in urls where url.pathExtension == "resume" {
            cleared += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            try? FileManager.default.removeItem(at: url)
        }
        return cleared
    }

    private func configureSession() {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.backgroundSessionIdentifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.timeoutIntervalForRequest = 90
        configuration.timeoutIntervalForResource = 7 * 24 * 60 * 60
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    private func restoreBackgroundTasks() {
        session.getAllTasks { [weak self] tasks in
            guard let self else { return }
            DispatchQueue.main.async {
                var connectedIDs = Set<UUID>()
                for task in tasks {
                    guard let description = task.taskDescription, let id = UUID(uuidString: description) else { continue }
                    connectedIDs.insert(id)
                    if let index = self.items.firstIndex(where: { $0.id == id }) {
                        self.items[index].taskIdentifier = task.taskIdentifier
                        self.items[index].status = task.state == .suspended ? .paused : .downloading
                    } else if let url = task.originalRequest?.url {
                        var recovered = DownloadItem(id: id, sourceURL: url, filename: task.response?.suggestedFilename)
                        recovered.status = .downloading
                        recovered.taskIdentifier = task.taskIdentifier
                        self.items.insert(recovered, at: 0)
                    }
                }

                for index in self.items.indices where self.items[index].status == .downloading && !connectedIDs.contains(self.items[index].id) {
                    self.items[index].status = .queued
                    self.items[index].taskIdentifier = nil
                }
                self.persistRecords(force: true)
                self.pumpQueue()
            }
        }
    }

    private func pumpQueue() {
        let limit = max(1, min(UserDefaults.standard.integer(forKey: "simultaneousDownloads").nonZero(or: 3), 6))
        let activeCount = items.filter { $0.status == .downloading && $0.taskIdentifier != nil }.count
        var slots = max(0, limit - activeCount)
        guard slots > 0 else { return }

        for index in items.indices where slots > 0 {
            guard items[index].status == .queued, items[index].taskIdentifier == nil else { continue }
            let item = items[index]
            let task: URLSessionDownloadTask
            if let resumeData = try? Data(contentsOf: resumeDataURL(for: item.id)), !resumeData.isEmpty {
                task = session.downloadTask(withResumeData: resumeData)
                try? FileManager.default.removeItem(at: resumeDataURL(for: item.id))
            } else {
                var request = URLRequest(url: item.sourceURL)
                request.httpMethod = "GET"
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.allowsCellularAccess = !UserDefaults.standard.bool(forKey: "wifiOnly")
                request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
                task = session.downloadTask(with: request)
            }
            task.taskDescription = item.id.uuidString
            if item.totalBytes > 0 { task.countOfBytesClientExpectsToReceive = item.totalBytes }
            items[index].status = .downloading
            items[index].taskIdentifier = task.taskIdentifier
            items[index].errorMessage = nil
            speedSamples[item.id] = (item.bytesWritten, Date())
            task.resume()
            LiveActivityController.shared.start(for: items[index])
            slots -= 1
        }
        persistRecords(force: true)
    }

    private func resumeDataURL(for id: UUID) -> URL {
        supportDirectory.appendingPathComponent("\(id.uuidString).resume")
    }

    private func clearTaskIdentifier(for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].taskIdentifier = nil
    }

    private func uniqueDestination(filename: String) -> URL {
        let sanitized = filename.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let baseURL = Self.downloadsDirectory.appendingPathComponent(sanitized)
        guard FileManager.default.fileExists(atPath: baseURL.path) else { return baseURL }

        let name = baseURL.deletingPathExtension().lastPathComponent
        let ext = baseURL.pathExtension
        for number in 2...9999 {
            let candidateName = ext.isEmpty ? "\(name) \(number)" : "\(name) \(number).\(ext)"
            let candidate = Self.downloadsDirectory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return Self.downloadsDirectory.appendingPathComponent(UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)"))
    }

    private func loadRecords() {
        guard let data = try? Data(contentsOf: recordsURL), let decoded = try? JSONDecoder().decode([DownloadItem].self, from: data) else { return }
        items = decoded
    }

    private func persistRecords(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastPersistenceDate) > 1 else { return }
        lastPersistenceDate = Date()
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: recordsURL, options: .atomic)
    }

    private func sendCompletionNotification(for item: DownloadItem) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        let content = UNMutableNotificationContent()
        content.title = "Download complete"
        content.body = item.filename
        content.sound = .default
        let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationPermissionIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let description = downloadTask.taskDescription, let id = UUID(uuidString: description) else { return }
        let now = Date()
        let previous = speedSamples[id] ?? (totalBytesWritten - bytesWritten, now)
        let interval = now.timeIntervalSince(previous.date)
        let measuredSpeed = interval > 0.15 ? Double(totalBytesWritten - previous.bytes) / interval : nil
        if measuredSpeed != nil { speedSamples[id] = (totalBytesWritten, now) }

        DispatchQueue.main.async {
            guard let index = self.items.firstIndex(where: { $0.id == id }) else { return }
            self.items[index].bytesWritten = totalBytesWritten
            if totalBytesExpectedToWrite > 0 { self.items[index].totalBytes = totalBytesExpectedToWrite }
            if let measuredSpeed, measuredSpeed > 0 {
                let oldSpeed = self.items[index].bytesPerSecond
                let smoothed = oldSpeed > 0 ? oldSpeed * 0.7 + measuredSpeed * 0.3 : measuredSpeed
                self.items[index].bytesPerSecond = smoothed
                if totalBytesExpectedToWrite > totalBytesWritten {
                    self.items[index].secondsRemaining = Double(totalBytesExpectedToWrite - totalBytesWritten) / smoothed
                }
            }
            self.persistRecords()
            LiveActivityController.shared.update(for: self.items[index])
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let description = downloadTask.taskDescription, let id = UUID(uuidString: description) else { return }
        let fallback = downloadTask.originalRequest?.url?.lastPathComponent
        let suggestedName = downloadTask.response?.suggestedFilename
        let filename = (suggestedName?.isEmpty == false ? suggestedName : fallback) ?? "Download"
        let destination = uniqueDestination(filename: filename)

        do {
            try FileManager.default.moveItem(at: location, to: destination)
            let size = Int64((try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            DispatchQueue.main.async {
                guard let index = self.items.firstIndex(where: { $0.id == id }) else { return }
                self.items[index].filename = destination.lastPathComponent
                self.items[index].kind = DownloadKind.infer(from: destination.lastPathComponent)
                self.items[index].localFilename = destination.lastPathComponent
                self.items[index].bytesWritten = max(self.items[index].bytesWritten, size)
                self.items[index].totalBytes = max(self.items[index].totalBytes, size)
                self.items[index].bytesPerSecond = 0
                self.items[index].secondsRemaining = 0
                self.items[index].status = .completed
                self.items[index].taskIdentifier = nil
                self.items[index].errorMessage = nil
                let completed = self.items[index]
                self.persistRecords(force: true)
                LiveActivityController.shared.update(for: completed, force: true)
                LiveActivityController.shared.end(for: completed)
                self.sendCompletionNotification(for: completed)
                NotificationCenter.default.post(name: .downloadLibraryDidChange, object: nil)
                self.pumpQueue()
            }
        } catch {
            DispatchQueue.main.async {
                guard let index = self.items.firstIndex(where: { $0.id == id }) else { return }
                self.items[index].status = .failed
                self.items[index].errorMessage = "Could not save the file: \(error.localizedDescription)"
                self.items[index].taskIdentifier = nil
                self.persistRecords(force: true)
                self.pumpQueue()
            }
        }
    }
}

extension DownloadManager: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let description = task.taskDescription, let id = UUID(uuidString: description) else { return }
        let nsError = error as NSError

        DispatchQueue.main.async {
            guard let index = self.items.firstIndex(where: { $0.id == id }) else { return }
            if self.items[index].status == .paused || self.items[index].status == .cancelled { return }

            if let resumeData = nsError.userInfo["NSURLSessionResumeData"] as? Data {
                try? resumeData.write(to: self.resumeDataURL(for: id), options: .atomic)
            }
            self.items[index].status = .failed
            self.items[index].bytesPerSecond = 0
            self.items[index].taskIdentifier = nil
            self.items[index].errorMessage = error.localizedDescription
            let failed = self.items[index]
            self.persistRecords(force: true)
            LiveActivityController.shared.update(for: failed, force: true)
            LiveActivityController.shared.end(for: failed)
            self.pumpQueue()
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                  let completion = appDelegate.backgroundSessionCompletionHandler else { return }
            appDelegate.backgroundSessionCompletionHandler = nil
            completion()
        }
    }
}

private extension Int {
    func nonZero(or fallback: Int) -> Int { self == 0 ? fallback : self }
}
