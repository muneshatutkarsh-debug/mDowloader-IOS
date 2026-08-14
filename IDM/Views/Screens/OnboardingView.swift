import SwiftUI

/// First-launch welcome screen.
///
/// Ultra-minimal, Apple-style: the logo mark on a blue gradient that matches the
/// app icon, the tagline, a single primary action, and a small credit line.
struct OnboardingView: View {
    let getStarted: () -> Void

    // Blues sampled directly from the app icon so the screen matches it.
    private let topBlue = Color(red: 0.239, green: 0.388, blue: 0.682)
    private let bottomBlue = Color(red: 0.153, green: 0.196, blue: 0.459)

    var body: some View {
        ZStack {
            // Blue gradient matching the icon.
            LinearGradient(
                colors: [topBlue, bottomBlue],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Soft glassy sheen from the top.
            LinearGradient(
                colors: [Color.white.opacity(0.10), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                // Hero logo mark.
                Image("LogoGlyph")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170, height: 170)
                    .shadow(color: .black.opacity(0.30), radius: 26, y: 14)

                // App name.
                Text("mDownloader")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 30)

                // Tagline.
                Text("Only Downloader you Need")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal, 32)

                Spacer()

                // Primary action.
                Button(action: getStarted) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(bottomBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(.white, in: Capsule())
                        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)

                // Credits.
                VStack(spacing: 3) {
                    Text("Made With \u{2764}\u{FE0F}")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                    Text("- by Munesh")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.top, 24)
                .padding(.bottom, 26)
            }
            .padding(.horizontal, 24)
        }
    }
}
