# mDownloader for iOS

mDownloader is a personal native SwiftUI download manager designed around the supplied light, dark, and Dynamic Island mockups. It uses Apple's background `URLSession` service so eligible HTTP and HTTPS transfers can continue when the app leaves the foreground.

## Included

- Native SwiftUI interface for iOS 17 and later
- Light, dark, and system appearance modes
- Original blue/red visual theme from the supplied mockups
- Uncapped background downloads using `URLSessionConfiguration.background`
- Pause, resume, retry, cancel, delete, progress, measured speed, and estimated time remaining
- Share Extension for links shared from Safari and other browsers
- Live Activity with compact, expanded Dynamic Island, and Lock Screen layouts
- Home Screen status widget
- Local download library with system share/export support
- Completion notifications
- XcodeGen project definition and a GitHub Actions unsigned-IPA build

## Important installation facts

GitHub Actions can compile the app without an Apple Developer account, but iOS will not install an unsigned IPA. The generated artifact must be signed before installation. A Windows sideloading tool or signing service can re-sign it with an Apple ID or certificate.

Free/personal signing is temporary and may not preserve every entitlement. The Share Extension, widget, Live Activity, and shared download database rely on the App Group entitlement `group.com.munesh.mDownloader`. If a signing tool removes that entitlement, the main app can still run through the storage fallback, but cross-extension features will not share state correctly.

Never add Apple IDs, passwords, signing certificates, or provisioning profiles to this public repository.

## Build the IPA on GitHub

1. Open the repository's **Actions** tab.
2. Select **Build unsigned IPA**.
3. Choose **Run workflow**.
4. When the run finishes, download the `mDownloader-unsigned-<commit>` artifact.
5. Extract `mDownloader-unsigned.ipa` and sign it with your chosen sideloading method.

The workflow also runs automatically for pushes and pull requests targeting `main`.

## Build with Xcode

On macOS with Xcode 16 or later:

```sh
brew install xcodegen
xcodegen generate
open mDownloader.xcodeproj
```

Select your signing team in Xcode before installing on a device. If you change the bundle identifier, also change the three target bundle identifiers and App Group identifier in `project.yml`, the entitlement files, and `Shared/AppGroup.swift` values currently held in `SharedStorage.swift`.

## How link handling works

The Share Extension accepts HTTP and HTTPS URLs. With **Ask before download** enabled, it shows a confirmation sheet. When disabled, it immediately schedules the transfer with the shared background session. The server ultimately controls the filename, resumability, range support, and maximum speed.

mDownloader downloads the response returned by a URL. It does not bypass DRM, authentication, paywalls, streaming protection, or a website's terms. Sharing a normal webpage may save HTML instead of detecting embedded media; direct file URLs work best.

## Repository layout

- `mDownloader/` â€” main SwiftUI app and download manager
- `mDownloaderShare/` â€” browser Share Extension
- `mDownloaderWidget/` â€” widget and Live Activity/Dynamic Island UI
- `Shared/` â€” models, App Group storage, and ActivityKit attributes
- `DesignReferences/` â€” supplied visual specification
- `.github/workflows/` â€” unsigned IPA build automation
- `project.yml` â€” XcodeGen project definition

## Privacy

All download metadata and files remain on the device. mDownloader has no analytics, account system, advertising, or custom backend.


