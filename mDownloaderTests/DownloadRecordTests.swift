import XCTest
@testable import mDownloader

final class DownloadRecordTests: XCTestCase {
    func testPercentTextClampsProgress() {
        let record = DownloadRecord(
            sourceURL: "https://example.com/file.zip",
            fileName: "file.zip",
            progress: 1.2
        )
        XCTAssertEqual(record.percentText, "100%")
    }

    func testActiveStates() {
        XCTAssertTrue(DownloadState.queued.isActive)
        XCTAssertTrue(DownloadState.downloading.isActive)
        XCTAssertTrue(DownloadState.paused.isActive)
        XCTAssertFalse(DownloadState.completed.isActive)
        XCTAssertFalse(DownloadState.failed.isActive)
    }

    func testRemainingTimeFormatting() {
        let record = DownloadRecord(
            sourceURL: "https://example.com/file.zip",
            fileName: "file.zip",
            estimatedSecondsRemaining: 180
        )
        XCTAssertEqual(record.remainingText, "3 min left")
    }
}

