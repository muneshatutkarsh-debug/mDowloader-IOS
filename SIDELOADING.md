# Build and install mDownloader privately

This route creates an unsigned iPhone IPA on a GitHub-hosted Mac and installs it privately from Windows. It does **not** upload the app to App Store Connect, request App Review, or publish the app.

## Part 1 — Build the unsigned IPA

1. Create a new **private** repository at GitHub.
2. Upload the contents of this project folder to the repository. Make sure the hidden `.github` folder is included.
3. Open the repository's **Actions** tab.
4. Select **Build private unsigned IPA**.
5. Press **Run workflow**, then confirm **Run workflow**.
6. When the run finishes, open it and download the **IDM-unsigned-IPA** artifact.
7. Extract the artifact. It contains:
   - `IDM-unsigned.ipa`
   - `IDM-unsigned.ipa.sha256`
   - `xcodebuild.log`

The workflow uses Xcode 16.4 on a GitHub macOS 15 runner. It builds for a physical iPhone with code signing disabled, verifies that the Live Activity extension is embedded, packages the `.app` as an IPA, and publishes only the downloadable workflow artifact. It uses no Apple Account, signing certificate, provisioning profile, or GitHub secret.

## Part 2 — Sign and install from Windows

You need a personal signing tool because iOS will not run an unsigned IPA. AltStore Classic is one established option:

1. Install AltServer for Windows from the official AltStore website.
2. Install the current Apple Devices/iTunes and iCloud components requested by AltServer.
3. Connect the iPhone to Windows by USB, tap **Trust**, and use AltServer to install AltStore.
4. On the iPhone, enable **Settings > Privacy & Security > Developer Mode** and restart when requested.
5. Copy `IDM-unsigned.ipa` to the iPhone, open AltStore, press **+** under **My Apps**, and select the IPA.
6. If asked about extensions, retain the `IDMLiveActivity` extension; Dynamic Island functionality depends on it.
7. Keep AltServer available on the same network and refresh the app before its signing profile expires.

With a free Apple Account, Apple makes the provisioning profile expire after seven days. This is not an App Store submission; the app simply needs to be refreshed/re-signed periodically. A paid Apple Developer Program membership is optional and does not require publishing the app.

## Troubleshooting

- **The Actions tab does not show the workflow:** confirm `.github/workflows/build-unsigned-ipa.yml` exists in the repository's default branch.
- **The build fails:** download `xcodebuild.log` from the run and use its first `error:` line to diagnose the source or project setting.
- **The app cannot be opened:** confirm Developer Mode is enabled and the signing profile has not expired.
- **The Dynamic Island does not appear:** use a supported iPhone, allow Live Activities in Settings, keep the embedded extension during signing, and start an actual download.
- **The app says it is no longer available:** refresh/re-sign it through AltStore; free profiles expire every seven days.
- **The background download stops:** iOS ultimately controls background transfer scheduling. Test using a direct HTTPS file URL rather than a streaming webpage.

Official references:

- Apple Personal Team limits: https://developer.apple.com/help/account/basics/about-your-developer-account
- Apple Developer Mode: https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device
- AltStore getting started: https://faq.altstore.io/altstore-classic/your-altstore


## Sending links to mDownloader

There are two ways to send a link from another app (Safari, X, Reddit, etc.) to mDownloader.

### 1. The "Download with mDownloader" share row (one tap)
Long-press a link -> **Share** -> **Download with mDownloader**. On some sideloading setups iOS blocks an extension from launching its host app; if the tap does not open mDownloader, use the Shortcut below (it always works).

### 2. The "Download with mDownloader" Shortcut (works everywhere — the Truecaller-style trick)
1. Open the **Shortcuts** app -> **+** to create a new shortcut.
2. Add the action **Download with mDownloader** (search "mDownloader").
3. Tap the shortcut's **(i)** -> enable **Show in Share Sheet**, and set **Share Sheet Types** to **URLs** (and Text).
4. Name it **Download with mDownloader**.

Now **Download with mDownloader** appears in every share sheet and reliably hands the link to the app — exactly like Truecaller's share action. It also works from the Action button and "Hey Siri, Download with mDownloader".
