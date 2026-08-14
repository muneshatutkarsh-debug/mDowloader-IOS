import ActivityKit
import Foundation

struct DownloadActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var fileName: String
        var progress: Double
        var speedText: String
        var remainingText: String
        var statusText: String
    }

    var downloadID: String
}

