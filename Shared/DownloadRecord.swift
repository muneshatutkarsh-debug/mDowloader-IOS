import Foundation

enum DownloadState: String, Codable, CaseIterable, Sendable {
    case queued
    case downloading
    case paused
    case completed
    case failed
    case cancelled

    var isActive: Bool {
        self == .queued || self == .downloading || self == .paused
    }
}

struct DownloadRecord: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var sourceURL: String
    var fileName: String
    var state: DownloadState
    var progress: Double
    var bytesWritten: Int64
    var totalBytes: Int64
    var bytesPerSecond: Double
    var estimatedSecondsRemaining: Double?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var localFileName: String?
    var errorMessage: String?
    var initiatedByShareExtension: Bool

    init(
        id: UUID = UUID(),
        sourceURL: String,
        fileName: String,
        state: DownloadState = .queued,
        progress: Double = 0,
        bytesWritten: Int64 = 0,
        totalBytes: Int64 = 0,
        bytesPerSecond: Double = 0,
        estimatedSecondsRemaining: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        localFileName: String? = nil,
        errorMessage: String? = nil,
        initiatedByShareExtension: Bool = false
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.fileName = fileName
        self.state = state
        self.progress = progress
        self.bytesWritten = bytesWritten
        self.totalBytes = totalBytes
        self.bytesPerSecond = bytesPerSecond
        self.estimatedSecondsRemaining = estimatedSecondsRemaining
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.localFileName = localFileName
        self.errorMessage = errorMessage
        self.initiatedByShareExtension = initiatedByShareExtension
    }
}

extension DownloadRecord {
    var source: URL? { URL(string: sourceURL) }

    var percentText: String {
        "\(Int((progress.clamped(to: 0...1) * 100).rounded()))%"
    }

    var speedText: String {
        guard bytesPerSecond > 0 else { return "Waiting…" }
        return "\(ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file))/s"
    }

    var sizeText: String {
        let count = totalBytes > 0 ? totalBytes : bytesWritten
        guard count > 0 else { return "Unknown size" }
        return ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    var remainingText: String? {
        guard let seconds = estimatedSecondsRemaining, seconds.isFinite, seconds >= 0 else { return nil }
        if seconds < 60 { return "< 1 min left" }
        if seconds < 3600 { return "\(Int(ceil(seconds / 60))) min left" }
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours) hr \(minutes) min left"
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

