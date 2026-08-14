import Foundation

enum DownloadStatus: String, Codable, CaseIterable {
    case queued
    case downloading
    case paused
    case completed
    case failed
    case cancelled

    var title: String {
        switch self {
        case .queued: "Queued"
        case .downloading: "Downloading"
        case .paused: "Paused"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }
}

enum DownloadKind: String, Codable, CaseIterable {
    case video, audio, document, archive, image, other

    /// Full-color file icons matching the supplied mDownloader mockups.
    var emoji: String {
        switch self {
        case .video: "🎬"
        case .audio: "🎵"
        case .document: "📄"
        case .archive: "📦"
        case .image: "🖼️"
        case .other: "📁"
        }
    }

    var symbol: String {
        switch self {
        case .video: "play.fill"
        case .audio: "music.note"
        case .document: "doc.text.fill"
        case .archive: "doc.zipper"
        case .image: "photo.fill"
        case .other: "doc.fill"
        }
    }

    static func infer(from filename: String) -> DownloadKind {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        if ["mp4", "mov", "m4v", "avi", "mkv", "webm"].contains(ext) { return .video }
        if ["mp3", "m4a", "aac", "wav", "flac", "ogg"].contains(ext) { return .audio }
        if ["pdf", "doc", "docx", "txt", "rtf", "pages", "xls", "xlsx", "ppt", "pptx"].contains(ext) { return .document }
        if ["zip", "rar", "7z", "tar", "gz"].contains(ext) { return .archive }
        if ["jpg", "jpeg", "png", "gif", "heic", "webp", "tiff"].contains(ext) { return .image }
        return .other
    }
}

struct DownloadItem: Identifiable, Codable, Hashable {
    let id: UUID
    var sourceURL: URL
    var filename: String
    var kind: DownloadKind
    var status: DownloadStatus
    var bytesWritten: Int64
    var totalBytes: Int64
    var bytesPerSecond: Double
    var secondsRemaining: Double?
    var localFilename: String?
    var taskIdentifier: Int?
    var createdAt: Date
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        filename: String? = nil,
        status: DownloadStatus = .queued
    ) {
        self.id = id
        self.sourceURL = sourceURL
        let suggestedName = filename?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.filename = suggestedName?.isEmpty == false ? suggestedName! : (sourceURL.lastPathComponent.isEmpty ? "Download" : sourceURL.lastPathComponent)
        self.kind = DownloadKind.infer(from: self.filename)
        self.status = status
        self.bytesWritten = 0
        self.totalBytes = 0
        self.bytesPerSecond = 0
        self.secondsRemaining = nil
        self.localFilename = nil
        self.taskIdentifier = nil
        self.createdAt = Date()
        self.errorMessage = nil
    }

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(bytesWritten) / Double(totalBytes), 0), 1)
    }

    var fileExtensionLabel: String {
        let ext = URL(fileURLWithPath: filename).pathExtension.uppercased()
        return ext.isEmpty ? "FILE" : ext
    }

    var formattedSpeed: String {
        guard bytesPerSecond > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file) + "/s"
    }

    /// Speed formatted for the Dynamic Island compact/minimal presentation.
    /// The number is always at least two digits (e.g. `02 MB/s`, `13 MB/s`) so
    /// the minimized island keeps a constant width instead of resizing as the
    /// speed moves between one and two digits.
    var compactSpeed: String {
        let bps = bytesPerSecond
        if bps >= 999_500 {
            return String(format: "%02d MB/s", Int((bps / 1_000_000).rounded()))
        }
        if bps >= 1_000 {
            return String(format: "%02d KB/s", Int((bps / 1_000).rounded()))
        }
        return "00 MB/s"
    }

    var formattedWritten: String {
        ByteCountFormatter.string(fromByteCount: bytesWritten, countStyle: .file)
    }

    var formattedTotal: String {
        guard totalBytes > 0 else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    var formattedTimeRemaining: String {
        guard let secondsRemaining, secondsRemaining.isFinite, secondsRemaining >= 0 else { return "Calculating…" }
        let total = Int(secondsRemaining.rounded())
        if total >= 3600 { return "\(total / 3600)h \((total % 3600) / 60)m" }
        if total >= 60 { return "\(total / 60)m \(total % 60)s" }
        return "\(total)s"
    }
}
