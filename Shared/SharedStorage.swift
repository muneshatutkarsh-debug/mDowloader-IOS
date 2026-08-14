import Foundation

enum AppGroup {
    static let identifier = "group.com.munesh.mDownloader"
    static let primaryBackgroundSession = "com.munesh.mDownloader.background"
    static let shareBackgroundSession = "com.munesh.mDownloader.share.background"
}

enum AppearanceMode: String, Codable, CaseIterable {
    case light
    case dark
    case system
}

enum AppTheme: String, Codable, CaseIterable {
    case basic
    case original
}

final class SharedStorage {
    static let shared = SharedStorage()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.munesh.mDownloader.storage")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: resumeDataDirectory, withIntermediateDirectories: true)
    }

    var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    var rootDirectory: URL {
        if let shared = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
            return shared
        }
        let fallback = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return fallback.appendingPathComponent("mDownloader", isDirectory: true)
    }

    var downloadsDirectory: URL {
        rootDirectory.appendingPathComponent("Downloads", isDirectory: true)
    }

    private var resumeDataDirectory: URL {
        rootDirectory.appendingPathComponent("ResumeData", isDirectory: true)
    }

    private var recordsURL: URL {
        rootDirectory.appendingPathComponent("downloads.json")
    }

    func loadRecords() -> [DownloadRecord] {
        queue.sync {
            guard let data = try? Data(contentsOf: recordsURL) else { return [] }
            return (try? decoder.decode([DownloadRecord].self, from: data)) ?? []
        }
    }

    func saveRecords(_ records: [DownloadRecord]) {
        queue.sync {
            guard let data = try? encoder.encode(records) else { return }
            try? data.write(to: recordsURL, options: [.atomic])
        }
    }

    func upsert(_ record: DownloadRecord) {
        var records = loadRecords()
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
        saveRecords(records)
    }

    func remove(id: UUID) {
        saveRecords(loadRecords().filter { $0.id != id })
        deleteResumeData(for: id)
    }

    func resumeData(for id: UUID) -> Data? {
        try? Data(contentsOf: resumeDataDirectory.appendingPathComponent("\(id.uuidString).resume"))
    }

    func saveResumeData(_ data: Data, for id: UUID) {
        try? data.write(
            to: resumeDataDirectory.appendingPathComponent("\(id.uuidString).resume"),
            options: [.atomic]
        )
    }

    func deleteResumeData(for id: UUID) {
        try? fileManager.removeItem(at: resumeDataDirectory.appendingPathComponent("\(id.uuidString).resume"))
    }

    func uniqueDestination(for suggestedName: String) -> URL {
        let sanitized = sanitizeFileName(suggestedName)
        let candidate = downloadsDirectory.appendingPathComponent(sanitized)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }

        let extensionName = candidate.pathExtension
        let stem = candidate.deletingPathExtension().lastPathComponent
        var index = 2
        while true {
            let name = extensionName.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(extensionName)"
            let next = downloadsDirectory.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: next.path) { return next }
            index += 1
        }
    }

    func localURL(for record: DownloadRecord) -> URL? {
        guard let fileName = record.localFileName else { return nil }
        let url = downloadsDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Download-\(Int(Date().timeIntervalSince1970))" : cleaned
    }
}

