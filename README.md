# mDownloader for iOS

A native SwiftUI download manager based on the supplied six-screen design. The project includes a background download engine, built-in browser, file library, settings, notifications, and an ActivityKit Live Activity with Dynamic Island layouts.

## Requirements

- macOS with Xcode 16 or newer
- iOS 17 or newer
- An Apple Development team for installing on a physical device
- A Dynamic Island iPhone to see the compact and expanded island presentations (other supported devices show the Lock Screen Live Activity)

## Run it

1. Open `IDM.xcodeproj` in Xcode.
2. Select the **IDM** project, then the **IDM** target, and choose your Apple Development team under Signing & Capabilities.
3. If `com.munesh.IDM` is unavailable to your team, change the bundle identifier for **IDM** and make the **IDMLiveActivity** identifier the same value plus `.LiveActivity`.
4. Choose an iPhone simulator or connected iPhone and press Run.
5. On a real device, allow Live Activities and notifications when iOS asks.

## Build a private IPA without owning a Mac

The project includes `.github/workflows/build-unsigned-ipa.yml`. Run it in a private GitHub repository to compile an unsigned device IPA using a GitHub-hosted macOS runner. It performs no App Store submission and requires no Apple credentials or signing secrets in GitHub.

See `SIDELOADING.md` for the complete GitHub Actions, Windows signing, iPhone installation, Developer Mode, and seven-day refresh workflow.

## What is implemented

- Pixel-conscious glass-style SwiftUI UI for onboarding, downloads, browser, files, download details, and settings
- Direct HTTP/HTTPS downloads with server-provided filenames
- A persistent `URLSessionConfiguration.background` session
- Pause/resume using resume data, cancellation, retry, queueing, and 1–6 simultaneous transfers
- Wi-Fi-only requests for new transfers
- Progress, measured speed, remaining-time estimate, and persisted download history
- Automatic recovery/reconnection to system-owned background tasks after relaunch
- Files saved under the app's `Documents/Downloads` directory
- Files app/iTunes file sharing, Quick Look previews, sharing, searching, and deletion
- `WKWebView` browser with search, shortcuts, history, bookmarks, attachment detection, and manual download action
- Completion notifications
- Lock Screen Live Activity plus compact, minimal, and expanded Dynamic Island layouts
- Generated 1024×1024 production app icon
- App privacy manifest declaring no tracking or collected data and the required local-settings/file-metadata API reasons

## Important iOS behavior

The background session lets iOS continue file transfers while the app is suspended or terminated by the system. iOS controls background scheduling and network throughput, so no app can guarantee a specific “high-speed” rate. mDownloader keeps transfers non-discretionary when launched in the foreground, enables connectivity waiting, supports multiple concurrent files, and avoids application-level buffering so the system can transfer directly to disk.

Live Activities can update from the app while it is executing and when iOS delivers background-session events. iOS may suspend the app between those events, so continuous second-by-second Dynamic Island updates while fully suspended require a server that sends ActivityKit push updates through APNs. Completion is still delivered when iOS wakes the app for the background session.

The browser captures direct file responses and `Content-Disposition: attachment` links. It intentionally does not bypass DRM, authentication, paywalls, or streaming-service protections. Download only content you own or are permitted to save.

## Recommended device test

1. Use a large direct HTTPS file from a server you control.
2. Start the download and confirm the Live Activity appears.
3. Lock the phone and leave it idle for several minutes.
4. Reopen mDownloader and verify progress/reconnection.
5. Pause, resume, then swipe the app away and confirm the system completes the transfer.
6. Open the saved file from the Files tab and share it.

## Project structure

- `IDM/Services/DownloadManager.swift` — persistent background transfer engine
- `IDM/Services/LiveActivityController.swift` — Live Activity lifecycle
- `IDM/Services/FileLibrary.swift` — on-device file indexing
- `IDM/Views` — all SwiftUI screens and reusable glass components
- `IDMLiveActivity` — WidgetKit/Dynamic Island extension
