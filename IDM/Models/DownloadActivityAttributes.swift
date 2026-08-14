import ActivityKit
import Foundation

struct DownloadActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var progress: Double
        var speed: String
        var compactSpeed: String
        var timeRemaining: String
        var status: String
    }

    var downloadID: UUID
    var filename: String
    var fileType: String
    /// Whether the app's Original theme is active, so the Live Activity can
    /// match the in-app look (logo-blue ring, gradient bar, red leading ball).
    var isOriginal: Bool
}

