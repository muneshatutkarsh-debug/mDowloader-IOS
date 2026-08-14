import Combine
import Foundation

struct StoredFile: Identifiable, Hashable {
    let url: URL
    let size: Int64
    let modifiedAt: Date

    var id: String { url.path }
    var name: String { url.lastPathComponent }
    var kind: DownloadKind { DownloadKind.infer(from: name) }
    var formattedSize: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
}

final class FileLibrary: ObservableObject {
    @Published private(set) var files: [StoredFile] = []
    private var observer: NSObjectProtocol?

    init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: .downloadLibraryDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func refresh() {
        let directory = DownloadManager.downloadsDirectory
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        files = urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { return nil }
            return StoredFile(
                url: url,
                size: Int64(values.fileSize ?? 0),
                modifiedAt: values.contentModificationDate ?? .distantPast
            )
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func files(for kind: DownloadKind?) -> [StoredFile] {
        guard let kind else { return files }
        return files.filter { $0.kind == kind }
    }

    func delete(_ file: StoredFile) {
        try? FileManager.default.removeItem(at: file.url)
        refresh()
    }
}

extension Notification.Name {
    static let downloadLibraryDidChange = Notification.Name("downloadLibraryDidChange")
}
