import SwiftUI

/// App navigation tabs, rendered by the native iOS 26 `TabView` (the Liquid
/// Glass dock) in `RootView`. Also used as deep-link targets from the Live
/// Activity (`idm://...`).
enum AppTab: Hashable {
    case downloads
    case files
    case settings
}
