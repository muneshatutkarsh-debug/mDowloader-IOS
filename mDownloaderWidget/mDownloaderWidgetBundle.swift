import SwiftUI
import WidgetKit

@main
struct mDownloaderWidgetBundle: WidgetBundle {
    var body: some Widget {
        DownloadStatusWidget()
        DownloadLiveActivity()
    }
}

